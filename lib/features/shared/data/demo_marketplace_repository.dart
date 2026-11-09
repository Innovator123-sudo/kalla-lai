import 'package:kalla_lai/features/shared/data/marketplace_repository.dart';
import 'package:kalla_lai/features/shared/domain/marketplace_models.dart';

class DemoMarketplaceRepository implements MarketplaceRepository {
  @override
  bool get isLive => false;

  @override
  Future<List<JobShift>> nearbyJobs({
    double radiusKm = 5,
    GeoPoint? origin,
  }) async {
    const jobs = [
      JobShift(
        id: 'KL-2041',
        role: 'Certified Electrician',
        location: GeoPoint(27.6766, 85.3473),
        area: 'Koteshwor, Kathmandu',
        rateNpr: 1800,
        shiftLabel: 'Today · 10:00–16:00',
        distanceKm: 1.8,
        employerVerified: true,
        description:
            'Inspect distribution panels and complete a scheduled safety check for a small commercial site.',
        skills: ['Electrical safety', 'Trade certificate'],
      ),
      JobShift(
        id: 'KL-2058',
        role: 'Commercial Plumber',
        location: GeoPoint(27.6728, 85.3242),
        area: 'Balkumari, Lalitpur',
        rateNpr: 2200,
        shiftLabel: 'Tomorrow · 08:00–15:00',
        distanceKm: 3.4,
        employerVerified: true,
        description:
            'Repair a leaking supply line and test fixtures in a commercial kitchen.',
        skills: ['Pipe repair', 'Own hand tools'],
      ),
      JobShift(
        id: 'KL-2072',
        role: 'HVAC Technician',
        location: GeoPoint(27.7102, 85.3222),
        area: 'Lazimpat, Kathmandu',
        rateNpr: 2500,
        shiftLabel: 'Fri · 09:00–17:00',
        distanceKm: 6.2,
        employerVerified: false,
        description:
            'Assist with preventive maintenance and document equipment checks.',
        skills: ['HVAC maintenance', 'Safety induction'],
      ),
    ];
    if (origin == null) return jobs;
    return [
      for (final job in jobs)
        JobShift(
          id: job.id,
          role: job.role,
          location: job.location,
          area: job.area,
          rateNpr: job.rateNpr,
          shiftLabel: job.shiftLabel,
          distanceKm: origin.distanceKmTo(job.location),
          employerVerified: job.employerVerified,
          description: job.description,
          skills: job.skills,
        ),
    ];
  }

  LedgerEntry initialLedgerEntry() => LedgerEntry(
    transactionId: 'KL-TXN-8A21',
    amountNpr: 1800,
    status: LedgerStatus.escrowFunded,
    updatedAt: DateTime(2026, 11, 6, 9),
  );
}
