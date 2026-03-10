import AppKit

enum BrandIcon {
    private static let assetName = NSImage.Name("MenuIcon")
    private static let resourceSubdirectory = "Brand"
    private static let rasterCandidates = [
        ("menu_icon", "png"),
        ("clashbar-icon", "png"),
    ]

    static let image: NSImage? = {
        for bundle in AppResourceBundleLocator.candidateBundles() {
            if let image = bundle.image(forResource: assetName) {
                return image
            }

            for (resourceName, resourceExtension) in rasterCandidates {
                if let url = bundle.url(
                    forResource: resourceName,
                    withExtension: resourceExtension,
                    subdirectory: resourceSubdirectory), let image = NSImage(contentsOf: url)
                {
                    return image
                }

                if let url = bundle.url(forResource: resourceName, withExtension: resourceExtension),
                   let image = NSImage(contentsOf: url)
                {
                    return image
                }
            }
        }
        return nil
    }()
}
