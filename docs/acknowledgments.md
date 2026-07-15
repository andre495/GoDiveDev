# Acknowledgments & external resources

GoDive is built on Apple’s platforms and a mix of open catalogs, third-party SDKs, and community data. This page lists **bundled reference material** and **optional services** the app may use. GoDive is not affiliated with these projects unless noted.

## 3D models

| Source | Used for |
|--------|----------|
| **[Meshy AI](https://www.meshy.ai/)** | Field Guide **3D hero** models (French Angelfish, Caribbean reef squid, green sea turtle, spotted eagle ray, great barracuda, sergeant major, rock beauty, red lionfish), exported as **USDZ** for on-device **RealityKit** viewing |

## Marine life catalog

| Source | Used for |
|--------|----------|
| **_Caribbean Reef Life_** (Mickey Charteris) | Caribbean species names, grouping, and natural-history copy cross-referenced during catalog authoring |
| **[FishBase](https://www.fishbase.org/)** | Scientific names, depth/size facts, and taxonomy for Caribbean saltwater **fish** (via public FishBase parquet extracts in our build pipeline) |
| **[SeaLifeBase](https://www.sealifebase.org/)** | Scientific names and facts for Caribbean **invertebrates** and other non-fish marine life |
| **[REEF.org](https://www.reef.org/)** | Tropical Western Atlantic (TWA) species checklist used to filter the bundled fish list toward diver-relevant reef species |
| **[Wikimedia Commons](https://commons.wikimedia.org/)** | Many bundled Field Guide **photos** (Creative Commons and public-domain works; individual file licenses apply on Wikimedia) |
| **[snorkelstj.com](https://www.snorkelstj.com/)** | Supplemental Caribbean ID gallery reference used when building and validating species common names |

User-added species, your tagged sightings, and photos from your **Photos** library are yours — they are not part of these bundled catalogs.

## Dive sites

| Source | Used for |
|--------|----------|
| **[OpenDiveMap](https://opendivemap.com/)** (“open dive map” reference catalog) | Bundled **Explore** reference sites — names, coordinates, and place metadata matched when you import dives or browse **All Sites** |

Sites you create manually or from import-only names are stored locally on your device.

## Dive log import

| Source | Used for |
|--------|----------|
| **[Garmin FIT SDK](https://github.com/garmin/fit-swift-sdk)** (Garmin) | Reading **`.fit`** files from supported Garmin dive computers |
| **Garmin product photography** ([Garmin](https://www.garmin.com/)) | Onboarding **Monitor equipment** micro-demo hero and list thumbnail (**Descent™ Mk3i** product image, bundled under **`Resources/OnboardingPhotos/`**) |
| **[Unsplash](https://unsplash.com/)** | Onboarding **Share experiences** micro-demo trip hero — tropical beach photograph ([license](https://unsplash.com/license)) |
| **[UDDF 3.2](https://www.standardsproject.org/)** (Universal Dive Data Format) | Reading **`.uddf`** exports (e.g. MacDive, Subsurface, and other UDDF-compatible apps) |

GoDive maps imported fields into its own dive model; vendor-specific field names are not stored as-is.

## Maps (runtime)

| Source | Used for |
|--------|----------|
| **Apple MapKit** | Default **Explore**, dive overview, and site-picker maps when no Google key is configured; reverse geocoding for time zones |
| **[Google Maps SDK for iOS](https://developers.google.com/maps/documentation/ios-sdk)** | Optional hybrid map tiles and markers when the app build includes a valid Google Maps API key |

Map use is described in [Privacy & data](privacy-and-data.md). Dive log contents are not uploaded to map providers for basic display.

## Optional cloud features

These require network access and developer configuration; they are **off** unless enabled in the app build.

| Source | Used for |
|--------|----------|
| **[Fishial.AI](https://fishial.ai/)** | Optional **Identify fish** on dive media — one cropped JPEG per request, plus optional dive coordinates in a header ([API terms](https://docs.fishial.ai/api)) |

## Marketing website

| Source | Used for |
|--------|----------|
| **[Wix](https://www.wix.com/)** (Premium) | Public product landing page for GoDive (site project **GoDive** / GoDive iOS), served at **[godiveios.com](https://godiveios.com)** with the domain registered at GoDaddy and connected to Wix |

The iPhone app does not embed or require Wix. The user guide remains on [GitHub Pages](https://andre495.github.io/GoDiveDev/).

## Apple platform services

| Service | Used for |
|---------|----------|
| **Sign in with Apple** | Account gate and profile association on device |
| **PhotoKit** | Attach dive photos and videos from your library |
| **Contacts** | Optional buddy name and avatar when you link a contact |

---

!!! note "Trademarks"
    Garmin, MacDive, Subsurface, Google Maps, Apple, Sign in with Apple, and other names are trademarks of their respective owners. GoDive references them only to describe compatible import and map features.

If you believe a bundled asset should be credited differently or removed, please open an issue on the [GoDiveDev repository](https://github.com/andre495/GoDiveDev).
