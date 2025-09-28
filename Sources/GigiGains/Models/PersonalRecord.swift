import Foundation
import CoreData

@objc(PersonalRecord)
public class PersonalRecord: NSManagedObject, Identifiable {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<PersonalRecord> {
        return NSFetchRequest<PersonalRecord>(entityName: "PersonalRecord")
    }

    // MARK: - Computed Properties

    /// Record type as an enum
    public var recordTypeEnum: RecordType {
        get {
            return RecordType(rawValue: recordType) ?? .oneRM
        }
        set {
            recordType = newValue.rawValue
        }
    }

    /// Description of the personal record
    public var recordDescription: String {
        switch recordTypeEnum {
        case .oneRM:
            return "\(value.formatted(.number.precision(.fractionLength(1)))) lbs 1RM"
        case .maxVolume:
            return "\(value.formatted(.number.precision(.fractionLength(1)))) lbs total volume"
        case .maxReps:
            if let weight = weight {
                return "\(reps ?? 0) reps @ \(weight.formatted(.number.precision(.fractionLength(1)))) lbs"
            } else {
                return "\(reps ?? 0) reps"
            }
        case .maxWeight:
            return "\(value.formatted(.number.precision(.fractionLength(1)))) lbs"
        case .endurance:
            return "\(Int(value)) seconds"
        }
    }

    /// Whether this is a recent record (within last 30 days)
    public var isRecent: Bool {
        return date.timeIntervalSinceNow > -30 * 24 * 60 * 60 // 30 days
    }

    /// Whether this record represents a significant improvement
    public var isSignificantImprovement: Bool {
        // This would typically be calculated against previous records
        // For now, we'll consider any record achieved at high RPE significant
        if let sourceSet = sourceSet {
            return sourceSet.rpe >= 8.5
        }
        return false
    }

    // MARK: - Validation

    /// Validates personal record data according to business rules
    public func validate() throws {
        guard value > 0 else {
            throw PersonalRecordValidationError.invalidValue("Record value must be positive")
        }

        guard RecordType(rawValue: recordType) != nil else {
            throw PersonalRecordValidationError.invalidRecordType("Invalid record type")
        }

        if let weight = weight, weight < 0 {
            throw PersonalRecordValidationError.invalidWeight("Weight must be non-negative")
        }

        if let reps = reps, reps <= 0 {
            throw PersonalRecordValidationError.invalidReps("Reps must be positive")
        }

        guard date <= Date() else {
            throw PersonalRecordValidationError.invalidDate("Record date cannot be in the future")
        }
    }

    // MARK: - Business Logic Methods

    /// Creates a personal record from an exercise set
    public static func createFromSet(_ exerciseSet: ExerciseSet,
                                   exercise: Exercise,
                                   recordType: RecordType,
                                   context: NSManagedObjectContext) throws -> PersonalRecord {
        let record = PersonalRecord(context: context)
        record.exercise = exercise
        record.sourceSet = exerciseSet
        record.recordTypeEnum = recordType
        record.date = exerciseSet.createdAt

        switch recordType {
        case .oneRM:
            record.value = exerciseSet.estimatedOneRM
            record.weight = exerciseSet.weight
            record.reps = exerciseSet.reps
        case .maxVolume:
            record.value = exerciseSet.volume
            record.weight = exerciseSet.weight
            record.reps = exerciseSet.reps
        case .maxReps:
            record.value = Double(exerciseSet.reps)
            record.weight = exerciseSet.weight
            record.reps = exerciseSet.reps
        case .maxWeight:
            record.value = exerciseSet.weight
            record.weight = exerciseSet.weight
            record.reps = exerciseSet.reps
        case .endurance:
            // For endurance, we'd need additional data
            record.value = Double(exerciseSet.reps)
        }

        try record.validate()
        return record
    }

    /// Updates record properties
    public func updateProperties(value: Double? = nil,
                               weight: Double? = nil,
                               reps: Int32? = nil,
                               notes: String? = nil) throws {
        if let value = value {
            self.value = value
        }

        if let weight = weight {
            self.weight = weight
        }

        if let reps = reps {
            self.reps = reps
        }

        if let notes = notes {
            self.notes = notes
        }

        try validate()
        modifiedAt = Date()
    }

    // MARK: - Core Data Overrides

    public override func awakeFromInsert() {
        super.awakeFromInsert()

        let now = Date()
        if id == nil { id = UUID() }
        if createdAt == nil { createdAt = now }
        modifiedAt = now
        date = now

        // Set default values
        value = 0
        recordType = RecordType.oneRM.rawValue
    }

    public override func willSave() {
        super.willSave()

        if isUpdated && !isDeleted {
            modifiedAt = Date()

            // Validate data before saving
            do {
                try validate()
            } catch {
                print("Validation error for PersonalRecord: \(error)")
            }
        }
    }
}

// MARK: - Supporting Types

public enum RecordType: String, CaseIterable {
    case oneRM = "1RM"
    case maxVolume = "maxVolume"
    case maxReps = "maxReps"
    case maxWeight = "maxWeight"
    case endurance = "endurance"

    public var displayName: String {
        switch self {
        case .oneRM:
            return "1 Rep Max"
        case .maxVolume:
            return "Max Volume"
        case .maxReps:
            return "Max Reps"
        case .maxWeight:
            return "Max Weight"
        case .endurance:
            return "Endurance"
        }
    }

    public var unit: String {
        switch self {
        case .oneRM, .maxWeight, .maxVolume:
            return "lbs"
        case .maxReps:
            return "reps"
        case .endurance:
            return "seconds"
        }
    }
}

// MARK: - Validation Errors

public enum PersonalRecordValidationError: Error, LocalizedError {
    case invalidValue(String)
    case invalidRecordType(String)
    case invalidWeight(String)
    case invalidReps(String)
    case invalidDate(String)

    public var errorDescription: String? {
        switch self {
        case .invalidValue(let message),
             .invalidRecordType(let message),
             .invalidWeight(let message),
             .invalidReps(let message),
             .invalidDate(let message):
            return message
        }
    }
}