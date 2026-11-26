import Foundation

struct LoadedStory {
    let manifest: StoryManifest
    let nodes: [String: StoryNode]
}

enum StoryLoaderError: Error, LocalizedError {
    case missingResource(String)

    var errorDescription: String? {
        switch self {
        case .missingResource(let name):
            return "Missing story JSON resource: \(name)"
        }
    }
}

final class StoryLoader {
    private let bundle: Bundle

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    func loadCatalog() throws -> StoryCatalog {
        let decoder = JSONDecoder()
        let catalogURL = try resourceURL(named: "catalog", subdirectory: "Story")
        let data = try Data(contentsOf: catalogURL)
        return try decoder.decode(StoryCatalog.self, from: data)
    }

    func loadStory(folder: String) throws -> LoadedStory {
        let decoder = JSONDecoder()
        let subdir = "Story/\(folder)"
        let manifestURL = try resourceURL(named: "manifest", subdirectory: subdir)
        let manifestData = try Data(contentsOf: manifestURL)
        let manifest = try decoder.decode(StoryManifest.self, from: manifestData)

        var allNodes: [String: StoryNode] = [:]
        for actName in ["act1", "act2", "act3"] {
            let actURL = try resourceURL(named: actName, subdirectory: subdir)
            let actData = try Data(contentsOf: actURL)
            let actFile = try decoder.decode(StoryActFile.self, from: actData)
            for node in actFile.nodes {
                allNodes[node.id] = node
            }
        }

        return LoadedStory(manifest: manifest, nodes: allNodes)
    }

    func loadStory() throws -> LoadedStory {
        let catalog = try loadCatalog()
        let folder = catalog.stories.first(where: { $0.id == catalog.defaultStoryId })?.folder ?? catalog.defaultStoryId
        return try loadStory(folder: folder)
    }

    private func resourceURL(named name: String, subdirectory: String) throws -> URL {
        if let url = bundle.url(forResource: name, withExtension: "json", subdirectory: subdirectory) {
            return url
        }
        if let url = bundle.url(forResource: name, withExtension: "json") {
            return url
        }
        if bundle != Bundle.main {
            if let url = Bundle.main.url(forResource: name, withExtension: "json", subdirectory: subdirectory)
                ?? Bundle.main.url(forResource: name, withExtension: "json") {
                return url
            }
        }
        throw StoryLoaderError.missingResource("\(subdirectory)/\(name).json")
    }

    static func interpolate(_ template: String, variables: [String: StoryValue]) -> String {
        var result = template
        for (key, value) in variables {
            let placeholder = "{\(key)}"
            if result.contains(placeholder) {
                result = result.replacingOccurrences(of: placeholder, with: value.stringRepresentation)
            }
        }
        return result
    }
}
