import Foundation

/// Parses **UDDF** (Universal Dive Data Format) XML — e.g. **MacDive** exports (`http://www.streit.cc/uddf/3.2/`) — into **`DiveActivity`** + **`DiveProfilePoint`** + **`DiveBuddyTag`** (not yet inserted).
///
/// Uses **`XMLParser`** (iOS-safe; **`XMLDocument`** / **`XMLElement`** are not available on iOS). Unmapped UDDF fields are listed in **`cursor/todo.md`** (UDDF section). **Tank:** **`tankdata`** (volume m³, begin/end pressure Pa→psi, optional **`tankmaterial`**) and per-waypoint **`tankpressure`** (Pa→psi on **`DiveProfilePoint.tankPressurePSI`**).
enum UddfDiveFileDecoder {

    /// Builds one **`DiveActivity`** per **`<dive>`** under **`profiledata`**, sorted by **`startTime`** (caller should insert in this order for chained **`diveNumber`**).
    static func buildDiveActivities(from data: Data) throws -> [DiveActivity] {
        guard !data.isEmpty else { throw UddfDecodeError.emptyFile }

        let engine = ParserEngine()
        let parser = XMLParser(data: data)
        parser.delegate = engine
        parser.shouldProcessNamespaces = true
        parser.shouldReportNamespacePrefixes = false

        guard parser.parse() else {
            if let err = engine.parseError {
                throw UddfDecodeError.invalidXML(underlying: err)
            }
            let underlying = parser.parserError ?? NSError(domain: "UddfDiveFileDecoder", code: 1, userInfo: [NSLocalizedDescriptionKey: "XML parse failed"])
            throw UddfDecodeError.invalidXML(underlying: underlying)
        }

        if let err = engine.parseError {
            throw UddfDecodeError.invalidXML(underlying: err)
        }

        guard engine.sawUddfRoot else {
            throw UddfDecodeError.missingUddfRoot
        }

        let rawImportVersion = engine.makeRawImportVersion()
        let sites = engine.sites
        let buddies = engine.buddies

        guard !engine.diveScratches.isEmpty else { throw UddfDecodeError.noDives }

        var activities: [DiveActivity] = []
        activities.reserveCapacity(engine.diveScratches.count)

        for scratch in engine.diveScratches {
            let activity = try buildOneDive(
                from: scratch,
                sites: sites,
                buddies: buddies,
                gasMixById: engine.gasMixO2ById,
                equipmentCatalog: engine.equipmentById,
                rawImportVersion: rawImportVersion
            )
            activities.append(activity)
        }

        activities.sort {
            if $0.startTime != $1.startTime { return $0.startTime < $1.startTime }
            return $0.id.uuidString < $1.id.uuidString
        }

        return activities
    }

    // MARK: - Dive scratch

    /// Maps MacDive **`<divenumber>`** onto persisted fields. **`0`** → hidden **`-`** in the logbook.
    static func diveNumberFields(fromUddfDiveNumber raw: Int?) -> (diveNumber: Int?, diveNumberExplicitlyNone: Bool) {
        guard let raw else { return (nil, false) }
        if raw == 0 { return (nil, true) }
        if raw > 0 { return (raw, false) }
        return (nil, false)
    }

    private struct DiveScratch {
        var diveId: String
        var linkRefs: [String] = []
        var uddfDiveNumber: Int?
        var datetimeRaw: String?
        var surfaceIntervalPassed: Double?
        var greatestDepth: Double?
        var diveDurationSeconds: Double?
        /// **`informationafterdive/lowesttemperature`** (thermodynamic temperature, often K).
        var lowestTemperatureThermodynamic: Double?
        var notesParagraphs: [String] = []
        var waypoints: [WaypointScratch] = []
        /// **`tankdata/tankvolume`** (m³).
        var tankVolumeCubicMeters: Double?
        /// **`tankdata/tankpressurebegin`** (Pa → **`tankPressureStartPSI`**).
        var tankPressureBeginPascals: Double?
        /// **`tankdata/tankpressureend`** (Pa).
        var tankPressureEndPascals: Double?
        /// **`tankdata/tankmaterial`** when present.
        var tankMaterial: String?
        /// **`tankdata/link/@ref`** → **`gasdefinitions/mix/@id`**.
        var tankMixRef: String?
        /// **`equipmentused/link/@ref`** from before/after dive sections.
        var equipmentUsedRefs: [String] = []
    }

    private struct WaypointScratch {
        var depth: Double?
        var divetime: Double?
        var temperature: Double?
        /// **`samples/waypoint/tankpressure`** (Pa).
        var tankPressurePascals: Double?
    }

    private static func buildOneDive(
        from scratch: DiveScratch,
        sites: [String: UddfSiteRecord],
        buddies: [String: UddfBuddyRecord],
        gasMixById: [String: Double],
        equipmentCatalog: [String: UddfEquipmentCatalogItem],
        rawImportVersion: String
    ) throws -> DiveActivity {
        let diveId = scratch.diveId

        guard let raw = scratch.datetimeRaw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty
        else {
            throw UddfDecodeError.missingDiveDateTime
        }

        let site = scratch.linkRefs.compactMap { sites[$0] }.first
        let watchSemantics = UddfMacDiveWatchDatetimeSemanticsResolver.classify(
            equipmentUsedRefs: scratch.equipmentUsedRefs,
            catalog: equipmentCatalog
        )
        guard let parsedStart = DiveDateTimeParsing.parseUddfDateTime(
            raw,
            siteTimeZoneHours: site?.timeZoneHours,
            siteLatitude: site?.latitude,
            siteLongitude: site?.longitude,
            siteLocationName: site?.locationName ?? site?.name,
            macDiveNaiveSemantics: watchSemantics
        )
        else {
            throw UddfDecodeError.missingDiveDateTime
        }
        let startTime = parsedStart.instant

        let surfaceIntervalSeconds = scratch.surfaceIntervalPassed.map { Int($0.rounded(.towardZero)) }

        let durationMinutes = max(1, Int(((scratch.diveDurationSeconds ?? 0) / 60.0).rounded(.towardZero)))
        let bottomTimeSeconds = scratch.diveDurationSeconds.map { Int($0.rounded(.towardZero)) }

        let notesJoined = scratch.notesParagraphs
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
        let notesNonEmpty = notesJoined.isEmpty ? nil : notesJoined

        let defaultTank = DiveActivityTankDefaults.resolvedSpecification()
        let tankMaterialTrimmed = scratch.tankMaterial?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let tankMaterialNonEmpty = (tankMaterialTrimmed?.isEmpty == false) ? tankMaterialTrimmed : nil

        var siteRef: String?
        var buddyRefs: [String] = []
        for ref in scratch.linkRefs {
            if sites[ref] != nil {
                siteRef = ref
            } else if buddies[ref] != nil {
                buddyRefs.append(ref)
            }
        }

        let linkedSite = siteRef.flatMap { sites[$0] }
        let coordinate: DiveCoordinate? = linkedSite.flatMap { rec in
            guard let lat = rec.latitude, let lon = rec.longitude else { return nil }
            return DiveCoordinate(latitude: lat, longitude: lon)
        }

        let waypoints = buildParsedWaypoints(from: scratch.waypoints, diveStart: startTime)

        let depthsOnly = waypoints.map(\.depthMeters)
        let maxFromProfile = depthsOnly.max()
        let maxDepthMeters = max(scratch.greatestDepth ?? 0, maxFromProfile ?? 0)

        let tempsC = waypoints.compactMap(\.temperatureCelsius)
        let waterTempAvgCelsius: Double? = tempsC.isEmpty ? nil : (tempsC.reduce(0, +) / Double(tempsC.count))
        let waterTempMaxCelsius: Double? = tempsC.max()
        let summaryMinC = scratch.lowestTemperatureThermodynamic.map { uddfThermodynamicTemperatureToCelsius($0) }
        let waterTempMinCelsius: Double? = [summaryMinC, tempsC.min()].compactMap { $0 }.min()

        let averageDepthMeters: Double? = depthsOnly.isEmpty ? nil : (depthsOnly.reduce(0, +) / Double(depthsOnly.count))

        let avgAscent = averageAscentRateMetersPerSecond(waypoints: waypoints.map { (time: $0.elapsedSeconds, depth: $0.depthMeters) })

        let gasResolved = scratch.tankMixRef
            .flatMap { gasMixById[$0] }
            .map { DiveGasMixImport.resolved(fromUddfO2: $0) }

        let diveNumberResolved = diveNumberFields(fromUddfDiveNumber: scratch.uddfDiveNumber)

        let activity = DiveActivity(
            source: .macDive,
            sourceDiveId: diveId,
            startTime: startTime,
            timeZoneOffsetSeconds: parsedStart.timeZoneOffsetSeconds,
            durationMinutes: durationMinutes,
            maxDepthMeters: maxDepthMeters,
            averageDepthMeters: averageDepthMeters,
            bottomTimeSeconds: bottomTimeSeconds,
            surfaceIntervalSeconds: surfaceIntervalSeconds,
            diveNumber: diveNumberResolved.diveNumber,
            diveNumberExplicitlyNone: diveNumberResolved.diveNumberExplicitlyNone,
            waterTempAvgCelsius: waterTempAvgCelsius,
            waterTempMaxCelsius: waterTempMaxCelsius,
            waterTempMinCelsius: waterTempMinCelsius,
            avgAscentRateMetersPerSecond: avgAscent,
            siteName: linkedSite?.name,
            locationName: linkedSite?.locationName,
            entryCoordinate: coordinate,
            notes: notesNonEmpty,
            tankMaterial: tankMaterialNonEmpty ?? defaultTank.materialLabel,
            tankVolumeDescription: defaultTank.storedDescription,
            tankPressureStartPSI: UddfTankPressureConversion.psi(fromPascals: scratch.tankPressureBeginPascals),
            tankPressureEndPSI: UddfTankPressureConversion.psi(fromPascals: scratch.tankPressureEndPascals),
            gasType: gasResolved?.gasType,
            oxygenMix: gasResolved?.oxygenMix,
            rawImportVersion: rawImportVersion
        )

        activity.uddfImportDatetimeRaw = raw
        activity.uddfWatchNaiveDatetimeSemantics = watchSemantics

        for ref in buddyRefs {
            guard let b = buddies[ref] else { continue }
            let name = b.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }
            activity.buddies.append(DiveBuddyImportConsolidation.makePendingTag(displayName: name))
        }

        let points: [DiveProfilePoint] = waypoints.map { wp in
            DiveProfilePoint(
                timestamp: wp.timestamp,
                depthMeters: wp.depthMeters,
                temperatureCelsius: wp.temperatureCelsius,
                ascentRateMetersPerSecond: wp.ascentRateMetersPerSecond,
                ndlSeconds: nil,
                timeToSurfaceSeconds: nil,
                tankPressurePSI: wp.tankPressurePSI,
                dive: activity
            )
        }
        activity.profilePoints = points
        activity.applyImportedGasConsumptionMetrics(volumeUsedSurfaceLiters: nil)

        return activity
    }

    // MARK: - Waypoints

    private struct ParsedWaypoint {
        var elapsedSeconds: Double
        var timestamp: Date
        var depthMeters: Double
        var temperatureCelsius: Double?
        var ascentRateMetersPerSecond: Double?
        var tankPressurePSI: Double?
    }

    private static func buildParsedWaypoints(from scratches: [WaypointScratch], diveStart: Date) -> [ParsedWaypoint] {
        var result: [ParsedWaypoint] = []
        result.reserveCapacity(scratches.count)

        var previous: (elapsed: Double, depth: Double)?

        for wp in scratches {
            let depth = wp.depth ?? 0
            let elapsed = wp.divetime ?? 0
            let tempC = wp.temperature.map { uddfThermodynamicTemperatureToCelsius($0) }
            let tankPSI = UddfTankPressureConversion.psi(fromPascals: wp.tankPressurePascals)

            let timestamp = diveStart.addingTimeInterval(elapsed)

            let rate: Double?
            if let prev = previous {
                let dt = elapsed - prev.elapsed
                if dt > 0 {
                    rate = (depth - prev.depth) / dt
                } else {
                    rate = nil
                }
            } else {
                rate = nil
            }

            result.append(
                ParsedWaypoint(
                    elapsedSeconds: elapsed,
                    timestamp: timestamp,
                    depthMeters: depth,
                    temperatureCelsius: tempC,
                    ascentRateMetersPerSecond: rate,
                    tankPressurePSI: tankPSI
                )
            )
            previous = (elapsed, depth)
        }

        return result
    }

    private static func uddfThermodynamicTemperatureToCelsius(_ value: Double) -> Double {
        if value > 200 { return value - 273.15 }
        return value
    }

    private static func averageAscentRateMetersPerSecond(waypoints: [(time: Double, depth: Double)]) -> Double? {
        var rates: [Double] = []
        for i in 1..<waypoints.count {
            let dt = waypoints[i].time - waypoints[i - 1].time
            guard dt > 0 else { continue }
            let dd = waypoints[i].depth - waypoints[i - 1].depth
            if dd < 0 { rates.append(-dd / dt) }
        }
        guard !rates.isEmpty else { return nil }
        return rates.reduce(0, +) / Double(rates.count)
    }

    // MARK: - Parser output types

    fileprivate struct UddfSiteRecord {
        var name: String?
        var locationName: String?
        var latitude: Double?
        var longitude: Double?
        /// **`geography/timezone`** — hours from UTC (UDDF float).
        var timeZoneHours: Double?
    }

    fileprivate struct UddfBuddyRecord {
        var displayName: String
    }

    // MARK: - Dates

    /// Parses ISO-like wall times from UDDF (legacy helper — prefer **`DiveDateTimeParsing`**).
    static func parseUddfDate(_ raw: String) -> Date? {
        DiveDateTimeParsing.parseUddfDateTime(raw)?.instant
    }

    // MARK: - XMLParser engine

    private final class ParserEngine: NSObject, XMLParserDelegate {

        private var elementStack: [String] = []
        private var textBuffer = ""

        var parseError: Error?
        var sawUddfRoot = false
        private(set) var uddfVersion: String?
        private(set) var generatorName: String?
        private(set) var generatorVersion: String?

        private(set) var sites: [String: UddfSiteRecord] = [:]
        private(set) var buddies: [String: UddfBuddyRecord] = [:]
        /// Mix **`id`** → raw **`<o2>`** (fraction or percent).
        private(set) var gasMixO2ById: [String: Double] = [:]
        private(set) var diveScratches: [DiveScratch] = []
        private(set) var equipmentById: [String: UddfEquipmentCatalogItem] = [:]

        private static let equipmentCatalogElementNames: Set<String> = [
            "buoyancycontroldevice", "boots", "camera", "compass", "compressor", "divecomputer",
            "fins", "gloves", "knife", "lead", "light", "mask", "rebreather", "regulator",
            "scooter", "suit", "tank", "variouspieces", "videocamera", "watch",
        ]

        private var currentEquipmentId: String?
        private var currentEquipmentKind: String?
        private var currentEquipmentName: String?
        private var currentEquipmentModel: String?
        private var currentEquipmentManufacturerName: String?

        private var mixId: String?
        private var mixO2Raw: Double?

        private var siteId: String?
        private var siteName: String?
        private var siteLocation: String?
        private var siteCountry: String?
        private var siteLatitude: Double?
        private var siteLongitude: Double?
        private var siteTimeZoneHours: Double?

        private var buddyId: String?
        private var buddyFirst: String?
        private var buddyLast: String?

        private var diveScratch: DiveScratch?
        private var waypointScratch: WaypointScratch?

        func makeRawImportVersion() -> String {
            let v = uddfVersion ?? "unknown"
            let gn = generatorName ?? "unknown"
            let gv = generatorVersion ?? "unknown"
            return "UDDF-\(v)-\(gn)-\(gv)"
        }

        private static func localName(_ elementName: String) -> String {
            if let colon = elementName.lastIndex(of: ":") {
                return String(elementName[elementName.index(after: colon)...])
            }
            return elementName
        }

        private func pathEnds(with suffix: [String]) -> Bool {
            guard elementStack.count >= suffix.count else { return false }
            return Array(elementStack.suffix(suffix.count)) == suffix
        }

        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String]) {
            let name = Self.localName(elementName)
            textBuffer = ""

            if name == "dive" {
                let underProfiledata = elementStack.contains("profiledata")
                elementStack.append(name)
                if underProfiledata {
                    let id = attributeDict["id"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? UUID().uuidString
                    diveScratch = DiveScratch(diveId: id)
                }
                return
            }

            elementStack.append(name)

            if Self.equipmentCatalogElementNames.contains(name),
               elementStack.contains("equipment"),
               let id = attributeDict["id"]?.trimmingCharacters(in: .whitespacesAndNewlines),
               !id.isEmpty {
                currentEquipmentId = id
                currentEquipmentKind = name
                currentEquipmentName = nil
                currentEquipmentModel = nil
                currentEquipmentManufacturerName = nil
            }

            switch name {
            case "uddf":
                sawUddfRoot = true
                if let v = attributeDict["version"]?.trimmingCharacters(in: .whitespacesAndNewlines), !v.isEmpty {
                    uddfVersion = v
                }
            case "site":
                siteId = attributeDict["id"]?.trimmingCharacters(in: .whitespacesAndNewlines)
                siteName = nil
                siteLocation = nil
                siteCountry = nil
                siteLatitude = nil
                siteLongitude = nil
                siteTimeZoneHours = nil
            case "buddy":
                buddyId = attributeDict["id"]?.trimmingCharacters(in: .whitespacesAndNewlines)
                buddyFirst = nil
                buddyLast = nil
            case "mix":
                mixId = attributeDict["id"]?.trimmingCharacters(in: .whitespacesAndNewlines)
                mixO2Raw = nil
            case "link":
                if var d = diveScratch, pathEnds(with: ["tankdata", "link"]),
                   let ref = attributeDict["ref"]?.trimmingCharacters(in: .whitespacesAndNewlines), !ref.isEmpty {
                    d.tankMixRef = ref
                    diveScratch = d
                } else if var d = diveScratch, pathEnds(with: ["informationbeforedive", "link"]),
                          let ref = attributeDict["ref"]?.trimmingCharacters(in: .whitespacesAndNewlines), !ref.isEmpty {
                    d.linkRefs.append(ref)
                    diveScratch = d
                } else if var d = diveScratch, elementStack.contains("equipmentused"),
                          let ref = attributeDict["ref"]?.trimmingCharacters(in: .whitespacesAndNewlines), !ref.isEmpty {
                    if !d.equipmentUsedRefs.contains(ref) {
                        d.equipmentUsedRefs.append(ref)
                    }
                    diveScratch = d
                }
            case "waypoint":
                guard diveScratch != nil else { break }
                waypointScratch = WaypointScratch()
            default:
                break
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            textBuffer += string
        }

        func parser(_ parser: XMLParser, foundCDATA CDATA: Data) {
            if let s = String(data: CDATA, encoding: .utf8) {
                textBuffer += s
            }
        }

        func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
            let name = Self.localName(elementName)
            let trimmed = textBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
            textBuffer = ""

            defer {
                if !elementStack.isEmpty, elementStack.last == name {
                    elementStack.removeLast()
                }
            }

            switch name {
            case "name":
                if pathEnds(with: ["site", "name"]), let id = siteId, !id.isEmpty {
                    siteName = trimmed.isEmpty ? nil : trimmed
                } else if pathEnds(with: ["generator", "name"]) {
                    generatorName = trimmed.isEmpty ? nil : trimmed
                } else if currentEquipmentId != nil, let kind = currentEquipmentKind,
                          pathEnds(with: [kind, "name"]) {
                    currentEquipmentName = trimmed.isEmpty ? nil : trimmed
                } else if currentEquipmentId != nil, let kind = currentEquipmentKind,
                          pathEnds(with: [kind, "manufacturer", "name"]) {
                    currentEquipmentManufacturerName = trimmed.isEmpty ? nil : trimmed
                }
            case "model":
                if currentEquipmentId != nil, let kind = currentEquipmentKind,
                   pathEnds(with: [kind, "model"]) {
                    currentEquipmentModel = trimmed.isEmpty ? nil : trimmed
                }
            case "version":
                if pathEnds(with: ["generator", "version"]) {
                    generatorVersion = trimmed.isEmpty ? nil : trimmed
                }
            case "location":
                if pathEnds(with: ["site", "geography", "location"]) {
                    siteLocation = trimmed.isEmpty ? nil : trimmed
                }
            case "country":
                if pathEnds(with: ["site", "geography", "address", "country"]) {
                    siteCountry = trimmed.isEmpty ? nil : trimmed
                }
            case "latitude":
                if pathEnds(with: ["site", "geography", "latitude"]) {
                    siteLatitude = Double(trimmed)
                }
            case "longitude":
                if pathEnds(with: ["site", "geography", "longitude"]) {
                    siteLongitude = Double(trimmed)
                }
            case "timezone":
                if pathEnds(with: ["site", "geography", "timezone"]) {
                    siteTimeZoneHours = Double(trimmed)
                }
            case "site":
                if let id = siteId, !id.isEmpty {
                    let locLine: String? = {
                        switch (siteLocation, siteCountry) {
                        case let (l?, c?): return "\(l), \(c)"
                        case let (l?, nil): return l
                        case let (nil, c?): return c
                        default: return nil
                        }
                    }()
                    sites[id] = UddfSiteRecord(
                        name: siteName,
                        locationName: locLine,
                        latitude: siteLatitude,
                        longitude: siteLongitude,
                        timeZoneHours: siteTimeZoneHours
                    )
                }
                siteId = nil
            case "firstname":
                if pathEnds(with: ["buddy", "personal", "firstname"]) {
                    buddyFirst = trimmed.isEmpty ? nil : trimmed
                }
            case "lastname":
                if pathEnds(with: ["buddy", "personal", "lastname"]) {
                    buddyLast = trimmed.isEmpty ? nil : trimmed
                }
            case "buddy":
                if let id = buddyId, !id.isEmpty {
                    let first = buddyFirst ?? ""
                    let last = buddyLast ?? ""
                    let combined = "\(first) \(last)".trimmingCharacters(in: .whitespacesAndNewlines)
                    let display = combined.isEmpty ? "Buddy" : combined
                    buddies[id] = UddfBuddyRecord(displayName: display)
                }
                buddyId = nil
            case "datetime":
                if var d = diveScratch, pathEnds(with: ["informationbeforedive", "datetime"]) {
                    d.datetimeRaw = trimmed.isEmpty ? nil : trimmed
                    diveScratch = d
                }
            case "passedtime":
                if var d = diveScratch, pathEnds(with: ["informationbeforedive", "surfaceintervalbeforedive", "passedtime"]) {
                    d.surfaceIntervalPassed = Double(trimmed)
                    diveScratch = d
                }
            case "divenumber":
                if var d = diveScratch, pathEnds(with: ["informationbeforedive", "divenumber"]) {
                    d.uddfDiveNumber = Int(trimmed)
                    diveScratch = d
                }
            case "divenumberofday":
                if var d = diveScratch,
                   pathEnds(with: ["informationbeforedive", "divenumberofday"]),
                   d.uddfDiveNumber == nil {
                    d.uddfDiveNumber = Int(trimmed)
                    diveScratch = d
                }
            case "greatestdepth":
                if var d = diveScratch, pathEnds(with: ["informationafterdive", "greatestdepth"]) {
                    d.greatestDepth = Double(trimmed)
                    diveScratch = d
                }
            case "lowesttemperature":
                if var d = diveScratch, pathEnds(with: ["informationafterdive", "lowesttemperature"]) {
                    d.lowestTemperatureThermodynamic = Double(trimmed)
                    diveScratch = d
                }
            case "diveduration":
                if var d = diveScratch, pathEnds(with: ["informationafterdive", "diveduration"]) {
                    d.diveDurationSeconds = Double(trimmed)
                    diveScratch = d
                }
            case "para":
                if var d = diveScratch, pathEnds(with: ["informationafterdive", "notes", "para"]), !trimmed.isEmpty {
                    d.notesParagraphs.append(trimmed)
                    diveScratch = d
                }
            case "depth":
                if var w = waypointScratch, pathEnds(with: ["samples", "waypoint", "depth"]) {
                    w.depth = Double(trimmed)
                    waypointScratch = w
                }
            case "divetime":
                if var w = waypointScratch, pathEnds(with: ["samples", "waypoint", "divetime"]) {
                    w.divetime = Double(trimmed)
                    waypointScratch = w
                }
            case "temperature":
                if var w = waypointScratch, pathEnds(with: ["samples", "waypoint", "temperature"]) {
                    w.temperature = Double(trimmed)
                    waypointScratch = w
                }
            case "tankpressure":
                if var w = waypointScratch, pathEnds(with: ["samples", "waypoint", "tankpressure"]) {
                    w.tankPressurePascals = Double(trimmed)
                    waypointScratch = w
                }
            case "o2":
                if pathEnds(with: ["gasdefinitions", "mix", "o2"]), let o2 = Double(trimmed) {
                    mixO2Raw = o2
                }
            case "mix":
                if let id = mixId, !id.isEmpty, let o2 = mixO2Raw {
                    gasMixO2ById[id] = o2
                }
                mixId = nil
                mixO2Raw = nil
            case "tankvolume":
                if var d = diveScratch, pathEnds(with: ["tankdata", "tankvolume"]) {
                    d.tankVolumeCubicMeters = Double(trimmed)
                    diveScratch = d
                }
            case "tankpressurebegin":
                if var d = diveScratch, pathEnds(with: ["tankdata", "tankpressurebegin"]) {
                    d.tankPressureBeginPascals = Double(trimmed)
                    diveScratch = d
                }
            case "tankpressureend":
                if var d = diveScratch, pathEnds(with: ["tankdata", "tankpressureend"]) {
                    d.tankPressureEndPascals = Double(trimmed)
                    diveScratch = d
                }
            case "tankmaterial":
                if var d = diveScratch, pathEnds(with: ["tankdata", "tankmaterial"]) {
                    d.tankMaterial = trimmed.isEmpty ? nil : trimmed
                    diveScratch = d
                }
            case "waypoint":
                if var d = diveScratch, let w = waypointScratch {
                    d.waypoints.append(w)
                    diveScratch = d
                }
                waypointScratch = nil
            case "dive":
                if let d = diveScratch, elementStack.contains("profiledata") {
                    diveScratches.append(d)
                }
                diveScratch = nil
            default:
                if Self.equipmentCatalogElementNames.contains(name),
                   let id = currentEquipmentId,
                   currentEquipmentKind == name {
                    equipmentById[id] = UddfEquipmentCatalogItem(
                        id: id,
                        kind: name,
                        name: currentEquipmentName ?? "",
                        model: currentEquipmentModel ?? "",
                        manufacturerName: currentEquipmentManufacturerName ?? ""
                    )
                    currentEquipmentId = nil
                    currentEquipmentKind = nil
                    currentEquipmentName = nil
                    currentEquipmentModel = nil
                    currentEquipmentManufacturerName = nil
                }
            }
        }

        func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
            self.parseError = parseError
        }
    }
}

// MARK: - Errors

enum UddfDecodeError: LocalizedError {
    case emptyFile
    case invalidXML(underlying: Error)
    case missingUddfRoot
    case noDives
    case missingDiveDateTime

    var errorDescription: String? {
        switch self {
        case .emptyFile:
            return "The file is empty."
        case .invalidXML(let underlying):
            return "Could not read UDDF XML: \(underlying.localizedDescription)"
        case .missingUddfRoot:
            return "This file is not a valid UDDF document (missing root)."
        case .noDives:
            return "No dives were found in this UDDF file."
        case .missingDiveDateTime:
            return "A dive is missing a start date and time."
        }
    }
}
