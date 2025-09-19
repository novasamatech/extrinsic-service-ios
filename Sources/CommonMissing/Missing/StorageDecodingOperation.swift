import Foundation
import SubstrateSdk
import Operation_iOS

public enum StorageDecodingOperationError: Error {
    case missingRequiredParams
    case invalidStoragePath
}

public protocol StorageDecodable {
    func decode(data: Data, path: StorageCodingPath, codingFactory: RuntimeCoderFactoryProtocol) throws -> JSON
}

public extension StorageDecodable {
    func decode(data: Data, path: StorageCodingPath, codingFactory: RuntimeCoderFactoryProtocol) throws -> JSON {
        guard let entry = codingFactory.metadata.getStorageMetadata(
            in: path.moduleName,
            storageName: path.itemName
        ) else {
            throw StorageDecodingOperationError.invalidStoragePath
        }

        let decoder = try codingFactory.createDecoder(from: data)
        return try decoder.read(type: entry.type.typeName)
    }
}

protocol StorageModifierHandling {
    func handleModifier(at path: StorageCodingPath, codingFactory: RuntimeCoderFactoryProtocol) throws -> JSON?
}

extension StorageModifierHandling {
    func handleModifier(at path: StorageCodingPath, codingFactory: RuntimeCoderFactoryProtocol) throws -> JSON? {
        guard let entry = codingFactory.metadata.getStorageMetadata(
            in: path.moduleName,
            storageName: path.itemName
        ) else {
            throw StorageDecodingOperationError.invalidStoragePath
        }

        switch entry.modifier {
        case .defaultModifier:
            let decoder = try codingFactory.createDecoder(from: entry.defaultValue)
            return try decoder.read(type: entry.type.typeName)
        case .optional:
            return nil
        }
    }
}

class StorageJSONDecodingOperation: BaseOperation<JSON>, StorageDecodable {
    var data: Data?
    var codingFactory: RuntimeCoderFactoryProtocol?

    let path: StorageCodingPath

    public init(path: StorageCodingPath, data: Data? = nil) {
        self.path = path
        self.data = data

        super.init()
    }

    override func performAsync(_ callback: @escaping (Result<JSON, Error>) -> Void) throws {
        do {
            guard let data = data, let factory = codingFactory else {
                throw StorageDecodingOperationError.missingRequiredParams
            }

            let item = try decode(data: data, path: path, codingFactory: factory)
            callback(.success(item))
        } catch {
            callback(.failure(error))
        }
    }
}

public final class StorageDecodingOperation<T: Decodable>: BaseOperation<T>, StorageDecodable {
    var data: Data?
    var codingFactory: RuntimeCoderFactoryProtocol?

    let path: StorageCodingPath

    public init(path: StorageCodingPath, data: Data? = nil) {
        self.path = path
        self.data = data

        super.init()
    }

    public override func performAsync(_ callback: @escaping (Result<T, Error>) -> Void) throws {
        do {
            guard let data = data, let factory = codingFactory else {
                throw StorageDecodingOperationError.missingRequiredParams
            }

            let item = try decode(data: data, path: path, codingFactory: factory).map(to: T.self)
            callback(.success(item))
        } catch {
            callback(.failure(error))
        }
    }
}

public final class StorageFallbackDecodingOperation<T: Decodable>: BaseOperation<T?>,
    StorageDecodable, StorageModifierHandling {
    var data: Data?
    var codingFactory: RuntimeCoderFactoryProtocol?

    let path: StorageCodingPath

    public init(path: StorageCodingPath, data: Data? = nil) {
        self.path = path
        self.data = data

        super.init()
    }

    public override func performAsync(_ callback: @escaping (Result<T?, Error>) -> Void) throws {
        do {
            guard let factory = codingFactory else {
                throw StorageDecodingOperationError.missingRequiredParams
            }

            if let data = data {
                let item = try decode(data: data, path: path, codingFactory: factory).map(to: T.self)
                callback(.success(item))
            } else {
                let item = try handleModifier(at: path, codingFactory: factory)?.map(to: T.self)
                callback(.success(item))
            }

        } catch {
            callback(.failure(error))
        }
    }
}

public final class StorageDecodingListOperation<T: Decodable>: BaseOperation<[T]>, StorageDecodable {
    var dataList: [Data]?
    var codingFactory: RuntimeCoderFactoryProtocol?

    let path: StorageCodingPath

    public init(path: StorageCodingPath, dataList: [Data]? = nil) {
        self.path = path
        self.dataList = dataList

        super.init()
    }

    public override func performAsync(_ callback: @escaping (Result<[T], Error>) -> Void) throws {
        do {
            guard let dataList = dataList, let factory = codingFactory else {
                throw StorageDecodingOperationError.missingRequiredParams
            }

            let items: [T] = try dataList.map { try decode(data: $0, path: path, codingFactory: factory)
                .map(to: T.self)
            }

            callback(.success(items))
        } catch {
            callback(.failure(error))
        }
    }
}

public final class StorageFallbackDecodingListOperation<T: Decodable>: BaseOperation<[T?]>,
    StorageDecodable, StorageModifierHandling {
    var dataList: [Data?]?
    var codingFactory: RuntimeCoderFactoryProtocol?
    var ignoresFailedItems: Bool

    let path: StorageCodingPath

    public init(path: StorageCodingPath, dataList: [Data?]? = nil, ignoresFailedItems: Bool = false) {
        self.path = path
        self.dataList = dataList
        self.ignoresFailedItems = ignoresFailedItems

        super.init()
    }

    public override func performAsync(_ callback: @escaping (Result<[T?], Error>) -> Void) throws {
        do {
            guard let dataList = dataList, let factory = codingFactory else {
                throw StorageDecodingOperationError.missingRequiredParams
            }

            let items: [T?] = try dataList.map { data in
                if let data = data {
                    let json: JSON?

                    if ignoresFailedItems {
                        json = try? decode(data: data, path: path, codingFactory: factory)
                    } else {
                        json = try decode(data: data, path: path, codingFactory: factory)
                    }

                    return try json?.map(to: T.self)
                } else {
                    return try handleModifier(at: path, codingFactory: factory)?.map(to: T.self)
                }
            }

            callback(.success(items))
        } catch {
            callback(.failure(error))
        }
    }
}

protocol ConstantDecodable {
    func decode(at path: ConstantCodingPath, codingFactory: RuntimeCoderFactoryProtocol) throws -> JSON
}

extension ConstantDecodable {
    func decode(at path: ConstantCodingPath, codingFactory: RuntimeCoderFactoryProtocol) throws -> JSON {
        guard let entry = codingFactory.metadata
            .getConstant(in: path.moduleName, constantName: path.constantName) else {
            throw StorageDecodingOperationError.invalidStoragePath
        }

        let decoder = try codingFactory.createDecoder(from: entry.value)
        return try decoder.read(type: entry.type)
    }
}

public final class StorageConstantOperation<T: Decodable>: BaseOperation<T>, ConstantDecodable {
    public var codingFactory: RuntimeCoderFactoryProtocol?

    let path: ConstantCodingPath

    let fallbackValue: T?

    public init(path: ConstantCodingPath, fallbackValue: T? = nil) {
        self.path = path
        self.fallbackValue = fallbackValue

        super.init()
    }

    public override func performAsync(_ callback: @escaping (Result<T, Error>) -> Void) throws {
        do {
            guard let factory = codingFactory else {
                throw StorageDecodingOperationError.missingRequiredParams
            }

            let item: T = try decode(at: path, codingFactory: factory).map(to: T.self)
            callback(.success(item))
        } catch {
            if
                let storageError = error as? StorageDecodingOperationError,
                storageError == .invalidStoragePath,
                let fallbackValue = fallbackValue {
                callback(.success(fallbackValue))
            } else {
                callback(.failure(error))
            }
        }
    }
}

public final class PrimitiveConstantOperation<T: LosslessStringConvertible & Equatable>: BaseOperation<T>, ConstantDecodable {
    public var codingFactory: RuntimeCoderFactoryProtocol?

    let oneOfPaths: [ConstantCodingPath]

    let fallbackValue: T?

    public init(path: ConstantCodingPath, fallbackValue: T? = nil) {
        oneOfPaths = [path]
        self.fallbackValue = fallbackValue

        super.init()
    }

    public init(oneOfPaths: [ConstantCodingPath], fallbackValue: T? = nil) {
        self.oneOfPaths = oneOfPaths
        self.fallbackValue = fallbackValue

        super.init()
    }

    public override func performAsync(_ callback: @escaping (Result<T, Error>) -> Void) throws {
        do {
            guard let factory = codingFactory, !oneOfPaths.isEmpty else {
                throw StorageDecodingOperationError.missingRequiredParams
            }

            let path = oneOfPaths.first { factory.hasConstant(for: $0) } ?? oneOfPaths[0]

            let item: StringScaleMapper<T> = try decode(at: path, codingFactory: factory)
                .map(to: StringScaleMapper<T>.self)
            callback(.success(item.value))
        } catch {
            if
                let storageError = error as? StorageDecodingOperationError,
                storageError == .invalidStoragePath,
                let fallbackValue = fallbackValue {
                callback(.success(fallbackValue))
            } else {
                callback(.failure(error))
            }
        }
    }
}

public final class StorageDecodingOptionalListOperation<T: Decodable>: BaseOperation<[T?]>, StorageDecodable {
    var dataList: [Data?]
    var codingFactory: RuntimeCoderFactoryProtocol?

    let path: StorageCodingPath

    public init(path: StorageCodingPath, dataList: [Data?]) {
        self.path = path
        self.dataList = dataList

        super.init()
    }

    public override func performAsync(_ callback: @escaping (Result<[T?], Error>) -> Void) throws {
        do {
            guard let factory = codingFactory else {
                throw StorageDecodingOperationError.missingRequiredParams
            }

            let items: [T?] = try dataList.map {
                guard let item = $0 else {
                    return nil
                }

                return try decode(data: item, path: path, codingFactory: factory).map(to: T.self)
            }

            callback(.success(items))
        } catch {
            callback(.failure(error))
        }
    }
}
