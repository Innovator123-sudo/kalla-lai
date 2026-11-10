import 'dart:math' as math;

import 'package:equatable/equatable.dart';

enum AppMode { vacancy, hiring }

enum VerificationStatus { pending, verified, needsAction, rejected }

enum DispatchStatus { confirmed, onTheWay, checkedIn, completionSubmitted }

enum LedgerStatus {
  escrowFunded,
  shiftInProgress,
  pendingClientReview,
  released,
  disputed,
}

class GeoPoint extends Equatable {
  const GeoPoint(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  /// Haversine great-circle distance in kilometres.
  double distanceKmTo(GeoPoint other) {
    const earthRadiusKm = 6371.0;
    double rad(double deg) => deg * math.pi / 180;
    final dLat = rad(other.latitude - latitude);
    final dLng = rad(other.longitude - longitude);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(rad(latitude)) *
            math.cos(rad(other.latitude)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  @override
  List<Object> get props => [latitude, longitude];
}

class JobShift extends Equatable {
  const JobShift({
    required this.id,
    required this.role,
    required this.location,
    required this.area,
    required this.rateNpr,
    required this.shiftLabel,
    required this.distanceKm,
    required this.employerVerified,
    required this.description,
    required this.skills,
    this.category = '',
    this.contactPhone = '',
    this.workingHours = '',
    this.employmentType = 'FULL_TIME',
    this.openings = 1,
    this.salaryIncrement = false,
    this.incrementNote = '',
    this.compensationType = 'DAILY',
    this.negotiable = true,
    this.googleMapsLink = '',
  });

  final String id;
  final String role;
  final GeoPoint location;
  final String area;
  final int rateNpr;
  final String shiftLabel;
  final double distanceKm;
  final bool employerVerified;
  final String description;
  final List<String> skills;
  final String category;
  final String contactPhone;
  final String workingHours;
  final String employmentType;
  final int openings;
  final bool salaryIncrement;
  final String incrementNote;
  final String compensationType;
  final bool negotiable;

  /// Optional Google Maps share link / pin supplied by the hirer.
  final String googleMapsLink;

  @override
  List<Object> get props => [
    id,
    role,
    location,
    area,
    rateNpr,
    shiftLabel,
    distanceKm,
    employerVerified,
    description,
    skills,
    category,
    contactPhone,
    workingHours,
    employmentType,
    openings,
    salaryIncrement,
    incrementNote,
    compensationType,
    negotiable,
    googleMapsLink,
  ];
}

class CounterOffer extends Equatable {
  const CounterOffer({required this.jobId, required this.amountNpr});

  final String jobId;
  final int amountNpr;

  @override
  List<Object> get props => [jobId, amountNpr];
}

class LedgerEntry extends Equatable {
  const LedgerEntry({
    required this.transactionId,
    required this.amountNpr,
    required this.status,
    required this.updatedAt,
  });

  final String transactionId;
  final int amountNpr;
  final LedgerStatus status;
  final DateTime updatedAt;

  @override
  List<Object> get props => [transactionId, amountNpr, status, updatedAt];
}

class RequisitionDraft extends Equatable {
  const RequisitionDraft({
    required this.role,
    required this.area,
    required this.shiftLabel,
    required this.rateNpr,
  });

  final String role;
  final String area;
  final String shiftLabel;
  final int rateNpr;

  @override
  List<Object> get props => [role, area, shiftLabel, rateNpr];
}
