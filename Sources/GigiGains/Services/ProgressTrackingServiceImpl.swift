//
//  ProgressTrackingServiceImpl.swift
//  Gigi Gains
//
//  Implementation of ProgressTrackingService protocol providing comprehensive
//  progress tracking, personal record calculations, and analytics.
//
//  Created: 2025-09-28
//

import Foundation
import CoreData
import Combine

public class ProgressTrackingServiceImpl: ProgressTrackingService {

    // MARK: - Properties

    private let workoutRepository: WorkoutRepository
    private let exerciseRepository: ExerciseRepository
    private let coreDataStack: CoreDataStack

    private let personalRecordsUpdateSubject = PassthroughSubject<[PersonalRecordData], Never>()
    private let weeklyVolumeUpdateSubject = PassthroughSubject<[VolumeData], Never>()
    private let progressSummaryUpdateSubject = PassthroughSubject<ProgressSummary, Never>()

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Publishers

    public var personalRecordsUpdatePublisher: AnyPublisher<[PersonalRecordData], Never> {
        personalRecordsUpdateSubject.eraseToAnyPublisher()
    }

    public var weeklyVolumeUpdatePublisher: AnyPublisher<[VolumeData], Never> {
        weeklyVolumeUpdateSubject.eraseToAnyPublisher()
    }

    public var progressSummaryUpdatePublisher: AnyPublisher<ProgressSummary, Never> {
        progressSummaryUpdateSubject.eraseToAnyPublisher()
    }

    // MARK: - Initialization

    public init(workoutRepository: WorkoutRepository, exerciseRepository: ExerciseRepository, coreDataStack: CoreDataStack) {
        self.workoutRepository = workoutRepository
        self.exerciseRepository = exerciseRepository
        self.coreDataStack = coreDataStack

        setupPublisherSubscriptions()
    }

    // MARK: - Personal Record Management

    public func getPersonalRecords(exerciseId: UUID) async throws -> [PersonalRecordData] {
        let context = coreDataStack.viewContext

        return try await context.perform {
            let request: NSFetchRequest<PersonalRecord> = PersonalRecord.fetchRequest()
            request.predicate = NSPredicate(format: "exercise.id == %@", exerciseId as CVarArg)
            request.sortDescriptors = [NSSortDescriptor(keyPath: \PersonalRecord.date, ascending: false)]

            do {
                let records = try context.fetch(request)
                return records.map { self.personalRecordToData($0) }
            } catch {
                throw ProgressTrackingError.coreDataError(error)
            }
        }
    }

    public func getPersonalRecords(exerciseId: UUID, recordType: PersonalRecordType) async throws -> [PersonalRecordData] {
        let context = coreDataStack.viewContext

        return try await context.perform {
            let request: NSFetchRequest<PersonalRecord> = PersonalRecord.fetchRequest()
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "exercise.id == %@", exerciseId as CVarArg),
                NSPredicate(format: "recordType == %@", recordType.rawValue)
            ])
            request.sortDescriptors = [NSSortDescriptor(keyPath: \PersonalRecord.date, ascending: false)]

            do {
                let records = try context.fetch(request)
                return records.map { self.personalRecordToData($0) }
            } catch {
                throw ProgressTrackingError.coreDataError(error)
            }
        }
    }

    public func getBestPersonalRecord(exerciseId: UUID, recordType: PersonalRecordType) async throws -> PersonalRecordData? {
        let records = try await getPersonalRecords(exerciseId: exerciseId, recordType: recordType)
        return records.max { $0.value < $1.value }
    }

    public func getPersonalRecords(period: ProgressTimePeriod) async throws -> [PersonalRecordData] {
        let dateRange = period.dateRange
        let context = coreDataStack.viewContext

        return try await context.perform {
            let request: NSFetchRequest<PersonalRecord> = PersonalRecord.fetchRequest()
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "date >= %@", dateRange.start as NSDate),
                NSPredicate(format: "date <= %@", dateRange.end as NSDate)
            ])
            request.sortDescriptors = [NSSortDescriptor(keyPath: \PersonalRecord.date, ascending: false)]

            do {
                let records = try context.fetch(request)
                return records.map { self.personalRecordToData($0) }
            } catch {
                throw ProgressTrackingError.coreDataError(error)
            }
        }
    }

    public func calculatePersonalRecords(fromSet setId: UUID, exerciseId: UUID) async throws -> [PersonalRecordData] {
        let context = coreDataStack.viewContext

        return try await context.perform {
            do {
                // Find the exercise set
                let setRequest: NSFetchRequest<ExerciseSet> = ExerciseSet.fetchRequest()
                setRequest.predicate = NSPredicate(format: "id == %@", setId as CVarArg)
                setRequest.fetchLimit = 1

                guard let exerciseSet = try context.fetch(setRequest).first else {
                    return []
                }

                // Find the exercise
                let exerciseRequest: NSFetchRequest<Exercise> = Exercise.fetchRequest()
                exerciseRequest.predicate = NSPredicate(format: "id == %@", exerciseId as CVarArg)
                exerciseRequest.fetchLimit = 1

                guard let exercise = try context.fetch(exerciseRequest).first else {
                    throw ProgressTrackingError.exerciseNotFound(exerciseId)
                }

                var newRecords: [PersonalRecordData] = []

                // Calculate 1RM using Epley formula: weight × (1 + reps/30)
                let estimatedOneRM = exerciseSet.estimatedOneRM
                if try self.isNewPersonalRecord(exercise: exercise, recordType: .oneRepMax, value: estimatedOneRM, context: context) {
                    let record = try self.createPersonalRecord(
                        exercise: exercise,
                        recordType: .oneRepMax,
                        value: estimatedOneRM,
                        weight: exerciseSet.weight,
                        reps: exerciseSet.reps,
                        sourceSet: exerciseSet,
                        context: context
                    )
                    newRecords.append(self.personalRecordToData(record))
                }

                // Check max weight
                if try self.isNewPersonalRecord(exercise: exercise, recordType: .maxWeight, value: exerciseSet.weight, context: context) {
                    let record = try self.createPersonalRecord(
                        exercise: exercise,
                        recordType: .maxWeight,
                        value: exerciseSet.weight,
                        weight: exerciseSet.weight,
                        reps: exerciseSet.reps,
                        sourceSet: exerciseSet,
                        context: context
                    )
                    newRecords.append(self.personalRecordToData(record))
                }

                // Check max reps at this weight
                if try self.isNewPersonalRecord(exercise: exercise, recordType: .maxReps, value: Double(exerciseSet.reps), weight: exerciseSet.weight, context: context) {
                    let record = try self.createPersonalRecord(
                        exercise: exercise,
                        recordType: .maxReps,
                        value: Double(exerciseSet.reps),
                        weight: exerciseSet.weight,
                        reps: exerciseSet.reps,
                        sourceSet: exerciseSet,
                        context: context
                    )
                    newRecords.append(self.personalRecordToData(record))
                }

                // Check max volume for single set
                let setVolume = exerciseSet.volume
                if try self.isNewPersonalRecord(exercise: exercise, recordType: .maxVolume, value: setVolume, context: context) {
                    let record = try self.createPersonalRecord(
                        exercise: exercise,
                        recordType: .maxVolume,
                        value: setVolume,
                        weight: exerciseSet.weight,
                        reps: exerciseSet.reps,
                        sourceSet: exerciseSet,
                        context: context
                    )
                    newRecords.append(self.personalRecordToData(record))
                }

                try context.save()

                if !newRecords.isEmpty {
                    Task { @MainActor in
                        self.personalRecordsUpdateSubject.send(newRecords)
                    }
                }

                return newRecords
            } catch {
                context.rollback()
                throw ProgressTrackingError.coreDataError(error)
            }
        }
    }

    public func recordPersonalRecord(exerciseId: UUID, recordType: PersonalRecordType, value: Double, weight: Double?, reps: Int32?, notes: String?) async throws -> PersonalRecordData {
        let context = coreDataStack.viewContext

        return try await context.perform {
            do {
                let exerciseRequest: NSFetchRequest<Exercise> = Exercise.fetchRequest()
                exerciseRequest.predicate = NSPredicate(format: "id == %@", exerciseId as CVarArg)
                exerciseRequest.fetchLimit = 1

                guard let exercise = try context.fetch(exerciseRequest).first else {
                    throw ProgressTrackingError.exerciseNotFound(exerciseId)
                }

                let record = try self.createPersonalRecord(
                    exercise: exercise,
                    recordType: recordType,
                    value: value,
                    weight: weight,
                    reps: reps,
                    sourceSet: nil,
                    context: context
                )

                if let notes = notes {
                    record.notes = notes
                }

                try context.save()

                let recordData = self.personalRecordToData(record)

                Task { @MainActor in
                    self.personalRecordsUpdateSubject.send([recordData])
                }

                return recordData
            } catch {
                context.rollback()
                throw ProgressTrackingError.coreDataError(error)
            }
        }
    }

    // MARK: - Volume Tracking and Analysis

    public func getWeeklyVolumeData(period: ProgressTimePeriod) async throws -> [VolumeData] {
        let dateRange = period.dateRange
        let context = coreDataStack.viewContext

        return try await context.perform {
            let request: NSFetchRequest<WeeklyVolume> = WeeklyVolume.fetchRequest()
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "weekStartDate >= %@", dateRange.start as NSDate),
                NSPredicate(format: "weekStartDate <= %@", dateRange.end as NSDate)
            ])
            request.sortDescriptors = [NSSortDescriptor(keyPath: \WeeklyVolume.weekStartDate, ascending: true)]

            do {
                let weeklyVolumes = try context.fetch(request)
                return weeklyVolumes.map { weeklyVolume in
                    VolumeData(
                        date: weeklyVolume.weekStartDate,
                        totalVolume: weeklyVolume.totalVolume,
                        totalSets: Int(weeklyVolume.totalSets),
                        totalReps: 0, // Would need to calculate from sets
                        averageRPE: weeklyVolume.averageRPE,
                        exerciseCount: 0, // Would need to calculate
                        workoutCount: Int(weeklyVolume.totalWorkouts)
                    )
                }
            } catch {
                throw ProgressTrackingError.coreDataError(error)
            }
        }
    }

    public func getExerciseVolumeData(exerciseId: UUID, period: ProgressTimePeriod) async throws -> [VolumeData] {
        let dateRange = period.dateRange
        let context = coreDataStack.viewContext

        return try await context.perform {
            do {
                // Get workout sessions in the date range
                let sessionRequest: NSFetchRequest<WorkoutSession> = WorkoutSession.fetchRequest()
                sessionRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                    NSPredicate(format: "startDate >= %@", dateRange.start as NSDate),
                    NSPredicate(format: "startDate <= %@", dateRange.end as NSDate),
                    NSPredicate(format: "isCompleted == YES")
                ])
                sessionRequest.sortDescriptors = [NSSortDescriptor(keyPath: \WorkoutSession.startDate, ascending: true)]
                sessionRequest.relationshipKeyPathsForPrefetching = ["exercises"]

                let sessions = try context.fetch(sessionRequest)

                var volumeDataPoints: [VolumeData] = []

                for session in sessions {
                    var sessionVolume: Double = 0
                    var sessionSets: Int = 0
                    var sessionReps: Int = 0
                    var totalRPE: Double = 0
                    var rpeCount: Int = 0

                    if let exercises = session.exercises?.allObjects as? [WorkoutExercise] {
                        for workoutExercise in exercises {
                            if workoutExercise.exercise?.id == exerciseId {
                                if let sets = workoutExercise.sets?.allObjects as? [ExerciseSet] {
                                    for set in sets where set.isCompleted {
                                        sessionVolume += set.volume
                                        sessionSets += 1
                                        sessionReps += Int(set.reps)

                                        if set.rpe > 0 {
                                            totalRPE += set.rpe
                                            rpeCount += 1
                                        }
                                    }
                                }
                            }
                        }
                    }

                    if sessionVolume > 0 {
                        volumeDataPoints.append(VolumeData(
                            date: session.startDate,
                            totalVolume: sessionVolume,
                            totalSets: sessionSets,
                            totalReps: sessionReps,
                            averageRPE: rpeCount > 0 ? totalRPE / Double(rpeCount) : nil,
                            exerciseCount: 1,
                            workoutCount: 1
                        ))
                    }
                }

                return volumeDataPoints
            } catch {
                throw ProgressTrackingError.coreDataError(error)
            }
        }
    }

    public func getTotalVolume(period: ProgressTimePeriod) async throws -> Double {
        let volumeData = try await getWeeklyVolumeData(period: period)
        return volumeData.reduce(0) { $0 + $1.totalVolume }
    }

    public func getVolumeByMuscleGroup(period: ProgressTimePeriod) async throws -> [String: Double] {
        let dateRange = period.dateRange
        let context = coreDataStack.viewContext

        return try await context.perform {
            do {
                let weeklyVolumeRequest: NSFetchRequest<WeeklyVolume> = WeeklyVolume.fetchRequest()
                weeklyVolumeRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                    NSPredicate(format: "weekStartDate >= %@", dateRange.start as NSDate),
                    NSPredicate(format: "weekStartDate <= %@", dateRange.end as NSDate)
                ])

                let weeklyVolumes = try context.fetch(weeklyVolumeRequest)
                var totalVolumeByMuscleGroup: [String: Double] = [:]

                for weeklyVolume in weeklyVolumes {
                    let muscleGroupVolumes = weeklyVolume.muscleGroupVolumesDict
                    for (muscleGroup, volume) in muscleGroupVolumes {
                        totalVolumeByMuscleGroup[muscleGroup, default: 0] += volume
                    }
                }

                return totalVolumeByMuscleGroup
            } catch {
                throw ProgressTrackingError.coreDataError(error)
            }
        }
    }

    public func compareVolume(currentPeriod: ProgressTimePeriod, previousPeriod: ProgressTimePeriod) async throws -> (current: Double, previous: Double, change: Double) {
        let currentVolume = try await getTotalVolume(period: currentPeriod)
        let previousVolume = try await getTotalVolume(period: previousPeriod)

        let change = previousVolume > 0 ? ((currentVolume - previousVolume) / previousVolume) * 100 : 0

        return (currentVolume, previousVolume, change)
    }

    // MARK: - Exercise Progress Analysis

    public func getExerciseProgress(exerciseId: UUID, period: ProgressTimePeriod) async throws -> ExerciseProgressData {
        let context = coreDataStack.viewContext

        return try await context.perform {
            do {
                let exerciseRequest: NSFetchRequest<Exercise> = Exercise.fetchRequest()
                exerciseRequest.predicate = NSPredicate(format: "id == %@", exerciseId as CVarArg)
                exerciseRequest.fetchLimit = 1

                guard let exercise = try context.fetch(exerciseRequest).first else {
                    throw ProgressTrackingError.exerciseNotFound(exerciseId)
                }

                let dateRange = period.dateRange

                // Get personal records for this exercise
                let personalRecords = try await self.getPersonalRecords(exerciseId: exerciseId)

                // Get current best 1RM
                let currentOneRM = try await self.getBestPersonalRecord(exerciseId: exerciseId, recordType: .oneRepMax)

                // Calculate previous period 1RM for comparison
                let previousPeriod = self.getPreviousPeriod(for: period)
                let previousOneRM = try await self.getBestPersonalRecordInPeriod(exerciseId: exerciseId, recordType: .oneRepMax, period: previousPeriod)

                // Calculate 1RM change
                let oneRMChange: Double?
                let oneRMChangePercent: Double?

                if let current = currentOneRM?.value, let previous = previousOneRM?.value {
                    oneRMChange = current - previous
                    oneRMChangePercent = (oneRMChange! / previous) * 100
                } else {
                    oneRMChange = nil
                    oneRMChangePercent = nil
                }

                // Get volume data for this exercise
                let volumeData = try await self.getExerciseVolumeData(exerciseId: exerciseId, period: period)
                let totalVolume = volumeData.reduce(0) { $0 + $1.totalVolume }

                // Calculate volume change
                let previousVolumeData = try await self.getExerciseVolumeData(exerciseId: exerciseId, period: previousPeriod)
                let previousTotalVolume = previousVolumeData.reduce(0) { $0 + $1.totalVolume }
                let volumeChange = previousTotalVolume > 0 ? ((totalVolume - previousTotalVolume) / previousTotalVolume) * 100 : nil

                // Calculate other statistics
                let averageRPE = volumeData.compactMap { $0.averageRPE }.isEmpty ? nil : volumeData.compactMap { $0.averageRPE }.reduce(0, +) / Double(volumeData.compactMap { $0.averageRPE }.count)
                let sessionCount = volumeData.count
                let totalSets = volumeData.reduce(0) { $0 + $1.totalSets }

                // Get recent performance data for charting
                let recentPerformance = try await self.getExercisePerformanceHistory(exerciseId: exerciseId, period: period)

                return ExerciseProgressData(
                    exerciseId: exerciseId,
                    exerciseName: exercise.name,
                    currentOneRM: currentOneRM?.value,
                    previousOneRM: previousOneRM?.value,
                    oneRMChange: oneRMChange,
                    oneRMChangePercent: oneRMChangePercent,
                    totalVolume: totalVolume,
                    volumeChange: volumeChange,
                    averageRPE: averageRPE,
                    sessionCount: sessionCount,
                    totalSets: totalSets,
                    personalRecords: personalRecords,
                    recentPerformance: recentPerformance
                )
            } catch {
                throw ProgressTrackingError.coreDataError(error)
            }
        }
    }

    public func getExercisesProgress(exerciseIds: [UUID], period: ProgressTimePeriod) async throws -> [ExerciseProgressData] {
        var progressData: [ExerciseProgressData] = []

        for exerciseId in exerciseIds {
            do {
                let progress = try await getExerciseProgress(exerciseId: exerciseId, period: period)
                progressData.append(progress)
            } catch ProgressTrackingError.exerciseNotFound {
                // Skip missing exercises
                continue
            }
        }

        return progressData
    }

    public func getMostImprovedExercises(period: ProgressTimePeriod, limit: Int) async throws -> [ExerciseProgressData] {
        // Get all exercises with recent activity
        let allExercises = try await exerciseRepository.fetchAllExercises()
        let progressData = try await getExercisesProgress(exerciseIds: allExercises.map { $0.id }, period: period)

        // Sort by improvement (1RM change percentage)
        let sortedProgress = progressData
            .filter { $0.oneRMChangePercent != nil && $0.oneRMChangePercent! > 0 }
            .sorted { ($0.oneRMChangePercent ?? 0) > ($1.oneRMChangePercent ?? 0) }

        return Array(sortedProgress.prefix(limit))
    }

    public func getExercisePerformanceHistory(exerciseId: UUID, period: ProgressTimePeriod) async throws -> [ExercisePerformancePoint] {
        let dateRange = period.dateRange
        let context = coreDataStack.viewContext

        return try await context.perform {
            do {
                // Get all completed sets for this exercise in the period
                let setRequest: NSFetchRequest<ExerciseSet> = ExerciseSet.fetchRequest()
                setRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                    NSPredicate(format: "workoutExercise.exercise.id == %@", exerciseId as CVarArg),
                    NSPredicate(format: "workoutExercise.session.startDate >= %@", dateRange.start as NSDate),
                    NSPredicate(format: "workoutExercise.session.startDate <= %@", dateRange.end as NSDate),
                    NSPredicate(format: "isCompleted == YES")
                ])
                setRequest.sortDescriptors = [NSSortDescriptor(keyPath: \ExerciseSet.createdAt, ascending: true)]
                setRequest.relationshipKeyPathsForPrefetching = ["workoutExercise.session"]

                let sets = try context.fetch(setRequest)

                return sets.map { set in
                    ExercisePerformancePoint(
                        date: set.workoutExercise?.session?.startDate ?? set.createdAt,
                        weight: set.weight,
                        reps: set.reps,
                        estimatedOneRM: set.estimatedOneRM,
                        rpe: set.rpe > 0 ? set.rpe : nil,
                        volume: set.volume
                    )
                }
            } catch {
                throw ProgressTrackingError.coreDataError(error)
            }
        }
    }

    // MARK: - Overall Progress Analysis

    public func getProgressSummary(period: ProgressTimePeriod) async throws -> ProgressSummary {
        let dateRange = period.dateRange

        let totalWorkouts = try await getTotalWorkouts(period: period)
        let totalVolume = try await getTotalVolume(period: period)

        // Calculate volume change
        let previousPeriod = getPreviousPeriod(for: period)
        let previousVolume = try await getTotalVolume(period: previousPeriod)
        let volumeChange = previousVolume > 0 ? ((totalVolume - previousVolume) / previousVolume) * 100 : nil

        let totalSets = try await getTotalSets(period: period)
        let averageWorkoutDuration = try await getAverageWorkoutDuration(period: period)
        let personalRecordsAchieved = try await getPersonalRecords(period: period).count
        let mostImprovedExercises = try await getMostImprovedExercises(period: period, limit: 5)
        let volumeByMuscleGroup = try await getVolumeByMuscleGroup(period: period)
        let averageRPE = try await getAverageRPE(period: period)
        let consistencyScore = try await getConsistencyScore(period: period)

        return ProgressSummary(
            period: period,
            totalWorkouts: totalWorkouts,
            totalVolume: totalVolume,
            volumeChange: volumeChange,
            totalSets: totalSets,
            averageWorkoutDuration: averageWorkoutDuration,
            personalRecordsAchieved: personalRecordsAchieved,
            mostImprovedExercises: mostImprovedExercises,
            volumeByMuscleGroup: volumeByMuscleGroup,
            averageRPE: averageRPE,
            consistencyScore: consistencyScore
        )
    }

    public func compareProgress(currentPeriod: ProgressTimePeriod, previousPeriod: ProgressTimePeriod) async throws -> (current: ProgressSummary, previous: ProgressSummary) {
        let current = try await getProgressSummary(period: currentPeriod)
        let previous = try await getProgressSummary(period: previousPeriod)
        return (current, previous)
    }

    public func getConsistencyScore(period: ProgressTimePeriod) async throws -> Double {
        let dateRange = period.dateRange
        let totalDays = dateRange.end.timeIntervalSince(dateRange.start) / (24 * 60 * 60)

        let workouts = try await getTotalWorkouts(period: period)
        let idealWorkoutsPerWeek = 4.0 // Assuming 4 workouts per week is ideal
        let totalWeeks = totalDays / 7
        let idealWorkouts = totalWeeks * idealWorkoutsPerWeek

        let consistency = min(Double(workouts) / idealWorkouts, 1.0)
        return max(consistency, 0.0)
    }

    public func getAchievements(period: ProgressTimePeriod) async throws -> [String] {
        let personalRecords = try await getPersonalRecords(period: period)
        var achievements: [String] = []

        for record in personalRecords {
            switch record.recordType {
            case .oneRepMax:
                achievements.append("New 1RM: \(record.exerciseName) - \(record.value.formatted(.number.precision(.fractionLength(1)))) lbs")
            case .maxWeight:
                achievements.append("New Max Weight: \(record.exerciseName) - \(record.value.formatted(.number.precision(.fractionLength(1)))) lbs")
            case .maxReps:
                if let weight = record.weight {
                    achievements.append("New Rep Record: \(record.exerciseName) - \(Int(record.value)) reps @ \(weight.formatted(.number.precision(.fractionLength(1)))) lbs")
                }
            case .maxVolume:
                achievements.append("New Volume Record: \(record.exerciseName) - \(record.value.formatted(.number.precision(.fractionLength(1)))) lbs total")
            case .endurance:
                achievements.append("New Endurance Record: \(record.exerciseName)")
            }
        }

        return achievements
    }

    // MARK: - Data Export

    public func exportProgressData(config: ExportConfig) async throws -> Data {
        switch config.format {
        case .csv:
            return try await exportToCSV(config: config)
        case .json:
            return try await exportToJSON(config: config)
        }
    }

    public func getExportPreview(config: ExportConfig) async throws -> String {
        switch config.format {
        case .csv:
            return "Session Date,Duration,Exercise,Set Number,Reps,Weight,RPE\n2024-01-15,45:30,Bench Press,1,8,135.0,7.5\n..."
        case .json:
            return "{\n  \"sessions\": [\n    {\n      \"date\": \"2024-01-15\",\n      \"exercises\": [...]\n    }\n  ]\n}"
        }
    }

    public func exportPersonalRecords(exerciseIds: [UUID]?, format: ExportFormat) async throws -> Data {
        let allRecords: [PersonalRecordData]

        if let exerciseIds = exerciseIds {
            var records: [PersonalRecordData] = []
            for exerciseId in exerciseIds {
                let exerciseRecords = try await getPersonalRecords(exerciseId: exerciseId)
                records.append(contentsOf: exerciseRecords)
            }
            allRecords = records
        } else {
            // Get all personal records
            let context = coreDataStack.viewContext
            allRecords = try await context.perform {
                let request: NSFetchRequest<PersonalRecord> = PersonalRecord.fetchRequest()
                request.sortDescriptors = [NSSortDescriptor(keyPath: \PersonalRecord.date, ascending: false)]

                do {
                    let records = try context.fetch(request)
                    return records.map { self.personalRecordToData($0) }
                } catch {
                    throw ProgressTrackingError.coreDataError(error)
                }
            }
        }

        switch format {
        case .csv:
            return try exportPersonalRecordsToCSV(allRecords)
        case .json:
            return try exportPersonalRecordsToJSON(allRecords)
        }
    }

    public func exportVolumeData(period: ProgressTimePeriod, format: ExportFormat) async throws -> Data {
        let volumeData = try await getWeeklyVolumeData(period: period)

        switch format {
        case .csv:
            return try exportVolumeDataToCSV(volumeData)
        case .json:
            return try exportVolumeDataToJSON(volumeData)
        }
    }

    // MARK: - Goal Tracking

    public func setGoal(exerciseId: UUID, recordType: PersonalRecordType, targetValue: Double, targetDate: Date?) async throws {
        // Goal tracking would be implemented with a Goal entity
        // For now, this is a placeholder
    }

    public func getActiveGoals() async throws -> [GoalData] {
        // Goal tracking would be implemented with a Goal entity
        // For now, return empty array
        return []
    }

    public func checkForAchievedGoals() async throws -> [GoalData] {
        // Goal tracking would be implemented with a Goal entity
        // For now, return empty array
        return []
    }

    public func updateGoalProgress() async throws {
        // Goal tracking would be implemented with a Goal entity
        // For now, this is a placeholder
    }

    // MARK: - Private Helper Methods

    private func setupPublisherSubscriptions() {
        workoutRepository.workoutSessionsChangedPublisher
            .sink { [weak self] in
                Task { @MainActor in
                    await self?.updateProgressPublishers()
                }
            }
            .store(in: &cancellables)
    }

    private func updateProgressPublishers() async {
        // Update publishers when workout data changes
        do {
            let recentRecords = try await getPersonalRecords(period: .month)
            personalRecordsUpdateSubject.send(recentRecords)

            let weeklyVolume = try await getWeeklyVolumeData(period: .month)
            weeklyVolumeUpdateSubject.send(weeklyVolume)

            let progressSummary = try await getProgressSummary(period: .month)
            progressSummaryUpdateSubject.send(progressSummary)
        } catch {
            print("Failed to update progress publishers: \(error)")
        }
    }

    private func personalRecordToData(_ record: PersonalRecord) -> PersonalRecordData {
        return PersonalRecordData(
            id: record.id,
            exerciseId: record.exercise?.id ?? UUID(),
            exerciseName: record.exercise?.name ?? "Unknown",
            recordType: PersonalRecordType(rawValue: record.recordType) ?? .oneRepMax,
            value: record.value,
            weight: record.weight,
            reps: record.reps,
            date: record.date,
            notes: record.notes,
            sourceSetId: record.sourceSet?.id
        )
    }

    private func isNewPersonalRecord(exercise: Exercise, recordType: PersonalRecordType, value: Double, weight: Double? = nil, context: NSManagedObjectContext) throws -> Bool {
        let request: NSFetchRequest<PersonalRecord> = PersonalRecord.fetchRequest()

        var predicates = [
            NSPredicate(format: "exercise == %@", exercise),
            NSPredicate(format: "recordType == %@", recordType.rawValue)
        ]

        // For max reps, we need to consider the weight
        if recordType == .maxReps, let weight = weight {
            predicates.append(NSPredicate(format: "weight == %f", weight))
        }

        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \PersonalRecord.value, ascending: false)]
        request.fetchLimit = 1

        do {
            let existingRecords = try context.fetch(request)
            return existingRecords.first?.value ?? 0 < value
        } catch {
            throw ProgressTrackingError.coreDataError(error)
        }
    }

    private func createPersonalRecord(exercise: Exercise, recordType: PersonalRecordType, value: Double, weight: Double?, reps: Int32?, sourceSet: ExerciseSet?, context: NSManagedObjectContext) throws -> PersonalRecord {
        let record = PersonalRecord(context: context)
        record.exercise = exercise
        record.recordTypeEnum = recordType
        record.value = value
        record.weight = weight
        record.reps = reps
        record.sourceSet = sourceSet
        record.date = Date()

        try record.validate()
        return record
    }

    private func getBestPersonalRecordInPeriod(exerciseId: UUID, recordType: PersonalRecordType, period: ProgressTimePeriod) async throws -> PersonalRecordData? {
        let dateRange = period.dateRange
        let context = coreDataStack.viewContext

        return try await context.perform {
            let request: NSFetchRequest<PersonalRecord> = PersonalRecord.fetchRequest()
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "exercise.id == %@", exerciseId as CVarArg),
                NSPredicate(format: "recordType == %@", recordType.rawValue),
                NSPredicate(format: "date >= %@", dateRange.start as NSDate),
                NSPredicate(format: "date <= %@", dateRange.end as NSDate)
            ])
            request.sortDescriptors = [NSSortDescriptor(keyPath: \PersonalRecord.value, ascending: false)]
            request.fetchLimit = 1

            do {
                guard let record = try context.fetch(request).first else {
                    return nil
                }
                return self.personalRecordToData(record)
            } catch {
                throw ProgressTrackingError.coreDataError(error)
            }
        }
    }

    private func getPreviousPeriod(for period: ProgressTimePeriod) -> ProgressTimePeriod {
        let calendar = Calendar.current

        switch period {
        case .week:
            let start = calendar.date(byAdding: .weekOfYear, value: -1, to: period.dateRange.start)!
            let end = calendar.date(byAdding: .weekOfYear, value: -1, to: period.dateRange.end)!
            return .custom(startDate: start, endDate: end)
        case .month:
            let start = calendar.date(byAdding: .month, value: -1, to: period.dateRange.start)!
            let end = calendar.date(byAdding: .month, value: -1, to: period.dateRange.end)!
            return .custom(startDate: start, endDate: end)
        case .quarter:
            let start = calendar.date(byAdding: .month, value: -3, to: period.dateRange.start)!
            let end = calendar.date(byAdding: .month, value: -3, to: period.dateRange.end)!
            return .custom(startDate: start, endDate: end)
        case .year:
            let start = calendar.date(byAdding: .year, value: -1, to: period.dateRange.start)!
            let end = calendar.date(byAdding: .year, value: -1, to: period.dateRange.end)!
            return .custom(startDate: start, endDate: end)
        case .allTime:
            return .custom(startDate: Date.distantPast, endDate: period.dateRange.start)
        case .custom(let startDate, let endDate):
            let duration = endDate.timeIntervalSince(startDate)
            let previousStart = startDate.addingTimeInterval(-duration)
            let previousEnd = startDate
            return .custom(startDate: previousStart, endDate: previousEnd)
        }
    }

    private func getTotalWorkouts(period: ProgressTimePeriod) async throws -> Int {
        let dateRange = period.dateRange
        let context = coreDataStack.viewContext

        return try await context.perform {
            let request: NSFetchRequest<WorkoutSession> = WorkoutSession.fetchRequest()
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "startDate >= %@", dateRange.start as NSDate),
                NSPredicate(format: "startDate <= %@", dateRange.end as NSDate),
                NSPredicate(format: "isCompleted == YES")
            ])

            do {
                return try context.count(for: request)
            } catch {
                throw ProgressTrackingError.coreDataError(error)
            }
        }
    }

    private func getTotalSets(period: ProgressTimePeriod) async throws -> Int {
        let volumeData = try await getWeeklyVolumeData(period: period)
        return volumeData.reduce(0) { $0 + $1.totalSets }
    }

    private func getAverageWorkoutDuration(period: ProgressTimePeriod) async throws -> TimeInterval? {
        let dateRange = period.dateRange
        let context = coreDataStack.viewContext

        return try await context.perform {
            let request: NSFetchRequest<WorkoutSession> = WorkoutSession.fetchRequest()
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "startDate >= %@", dateRange.start as NSDate),
                NSPredicate(format: "startDate <= %@", dateRange.end as NSDate),
                NSPredicate(format: "isCompleted == YES"),
                NSPredicate(format: "endDate != nil")
            ])

            do {
                let sessions = try context.fetch(request)
                guard !sessions.isEmpty else { return nil }

                let totalDuration = sessions.compactMap { session in
                    session.endDate?.timeIntervalSince(session.startDate)
                }.reduce(0, +)

                return totalDuration / Double(sessions.count)
            } catch {
                throw ProgressTrackingError.coreDataError(error)
            }
        }
    }

    private func getAverageRPE(period: ProgressTimePeriod) async throws -> Double? {
        let volumeData = try await getWeeklyVolumeData(period: period)
        let rpeValues = volumeData.compactMap { $0.averageRPE }

        guard !rpeValues.isEmpty else { return nil }
        return rpeValues.reduce(0, +) / Double(rpeValues.count)
    }

    // MARK: - Export Helper Methods

    private func exportToCSV(config: ExportConfig) async throws -> Data {
        var csvContent = "Session Date,Duration,Exercise,Set Number,Reps,Weight,RPE\n"

        let dateRange = config.dateRange
        let context = coreDataStack.viewContext

        return try await context.perform {
            let sessionRequest: NSFetchRequest<WorkoutSession> = WorkoutSession.fetchRequest()

            if let dateRange = dateRange {
                sessionRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                    NSPredicate(format: "startDate >= %@", dateRange.start as NSDate),
                    NSPredicate(format: "startDate <= %@", dateRange.end as NSDate),
                    NSPredicate(format: "isCompleted == YES")
                ])
            } else {
                sessionRequest.predicate = NSPredicate(format: "isCompleted == YES")
            }

            sessionRequest.sortDescriptors = [NSSortDescriptor(keyPath: \WorkoutSession.startDate, ascending: true)]
            sessionRequest.relationshipKeyPathsForPrefetching = ["exercises", "exercises.sets", "exercises.exercise"]

            do {
                let sessions = try context.fetch(sessionRequest)

                for session in sessions {
                    let duration = session.endDate?.timeIntervalSince(session.startDate) ?? 0
                    let durationString = String(format: "%.0f", duration / 60) // minutes

                    if let exercises = session.exercises?.allObjects as? [WorkoutExercise] {
                        for workoutExercise in exercises {
                            let exerciseName = workoutExercise.exercise?.name ?? "Unknown"

                            if let exerciseIds = config.exerciseIds, !exerciseIds.contains(workoutExercise.exercise?.id ?? UUID()) {
                                continue
                            }

                            if let sets = workoutExercise.sets?.allObjects as? [ExerciseSet] {
                                for (index, set) in sets.enumerated() where set.isCompleted {
                                    let dateFormatter = DateFormatter()
                                    dateFormatter.dateFormat = "yyyy-MM-dd"
                                    let dateString = dateFormatter.string(from: session.startDate)

                                    csvContent += "\(dateString),\(durationString),\(exerciseName),\(index + 1),\(set.reps),\(set.weight),\(set.rpe)\n"
                                }
                            }
                        }
                    }
                }

                return csvContent.data(using: .utf8) ?? Data()
            } catch {
                throw ProgressTrackingError.exportFailed("CSV export failed: \(error.localizedDescription)")
            }
        }
    }

    private func exportToJSON(config: ExportConfig) async throws -> Data {
        // JSON export implementation
        let exportData: [String: Any] = [
            "export_date": ISO8601DateFormatter().string(from: Date()),
            "format": "json",
            "sessions": []
        ]

        do {
            return try JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
        } catch {
            throw ProgressTrackingError.exportFailed("JSON export failed: \(error.localizedDescription)")
        }
    }

    private func exportPersonalRecordsToCSV(_ records: [PersonalRecordData]) throws -> Data {
        var csvContent = "Date,Exercise,Record Type,Value,Weight,Reps,Notes\n"

        for record in records {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dateString = dateFormatter.string(from: record.date)

            let weightString = record.weight?.formatted(.number.precision(.fractionLength(1))) ?? ""
            let repsString = record.reps != nil ? String(record.reps!) : ""
            let notesString = record.notes?.replacingOccurrences(of: "\"", with: "\"\"") ?? ""

            csvContent += "\(dateString),\(record.exerciseName),\(record.recordType.description),\(record.value),\(weightString),\(repsString),\"\(notesString)\"\n"
        }

        return csvContent.data(using: .utf8) ?? Data()
    }

    private func exportPersonalRecordsToJSON(_ records: [PersonalRecordData]) throws -> Data {
        let exportData: [String: Any] = [
            "export_date": ISO8601DateFormatter().string(from: Date()),
            "personal_records": records.map { record in
                [
                    "id": record.id.uuidString,
                    "exercise_id": record.exerciseId.uuidString,
                    "exercise_name": record.exerciseName,
                    "record_type": record.recordType.rawValue,
                    "value": record.value,
                    "weight": record.weight,
                    "reps": record.reps,
                    "date": ISO8601DateFormatter().string(from: record.date),
                    "notes": record.notes
                ]
            }
        ]

        do {
            return try JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
        } catch {
            throw ProgressTrackingError.exportFailed("JSON export failed: \(error.localizedDescription)")
        }
    }

    private func exportVolumeDataToCSV(_ volumeData: [VolumeData]) throws -> Data {
        var csvContent = "Date,Total Volume,Total Sets,Total Reps,Average RPE,Exercise Count,Workout Count\n"

        for data in volumeData {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dateString = dateFormatter.string(from: data.date)

            let averageRPEString = data.averageRPE?.formatted(.number.precision(.fractionLength(1))) ?? ""

            csvContent += "\(dateString),\(data.totalVolume),\(data.totalSets),\(data.totalReps),\(averageRPEString),\(data.exerciseCount),\(data.workoutCount)\n"
        }

        return csvContent.data(using: .utf8) ?? Data()
    }

    private func exportVolumeDataToJSON(_ volumeData: [VolumeData]) throws -> Data {
        let exportData: [String: Any] = [
            "export_date": ISO8601DateFormatter().string(from: Date()),
            "volume_data": volumeData.map { data in
                [
                    "date": ISO8601DateFormatter().string(from: data.date),
                    "total_volume": data.totalVolume,
                    "total_sets": data.totalSets,
                    "total_reps": data.totalReps,
                    "average_rpe": data.averageRPE,
                    "exercise_count": data.exerciseCount,
                    "workout_count": data.workoutCount
                ]
            }
        ]

        do {
            return try JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
        } catch {
            throw ProgressTrackingError.exportFailed("JSON export failed: \(error.localizedDescription)")
        }
    }
}