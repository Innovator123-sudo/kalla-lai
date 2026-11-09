import 'package:flutter/material.dart';

/// A selected job type: the specific title plus its broad category.
class JobTypeSelection {
  const JobTypeSelection(this.title, this.category);
  final String title;
  final String category;
}

/// Icons used for each job category across the picker and listings.
const Map<String, IconData> jobCategoryIcons = {
  'Technology & IT': Icons.computer_outlined,
  'Design & Creative': Icons.palette_outlined,
  'Construction & Trades': Icons.construction_outlined,
  'Hospitality & Food': Icons.restaurant_outlined,
  'Transport & Delivery': Icons.local_shipping_outlined,
  'Home & Personal Services': Icons.home_repair_service_outlined,
  'Business & Admin': Icons.business_center_outlined,
  'Education & Training': Icons.school_outlined,
  'Health & Care': Icons.medical_services_outlined,
  'Events & Media': Icons.celebration_outlined,
  'Beauty & Wellness': Icons.spa_outlined,
  'Security & Safety': Icons.security_outlined,
  'Agriculture & Farming': Icons.agriculture_outlined,
  'Retail & Sales': Icons.storefront_outlined,
};

/// 100+ common job types grouped by category. Employers pick one when posting
/// work; they can also type a custom title in the wizard.
const Map<String, List<String>> jobCatalog = {
  'Technology & IT': [
    'Chief Coder',
    'Software Engineer',
    'Frontend Developer',
    'Backend Developer',
    'Full-Stack Developer',
    'Mobile App Developer',
    'DevOps Engineer',
    'Data Analyst',
    'Data Entry Clerk',
    'QA Tester',
    'IT Support Technician',
    'Network Administrator',
    'Database Administrator',
    'Cybersecurity Analyst',
  ],
  'Design & Creative': [
    'Graphic Designer',
    'UI/UX Designer',
    'Web Designer',
    'Illustrator',
    'Motion Graphics Artist',
    'Video Editor',
    '3D Artist',
    'Brand Designer',
    'Interior Designer',
    'Fashion Designer',
  ],
  'Construction & Trades': [
    'Certified Electrician',
    'Commercial Plumber',
    'Mason',
    'Carpenter',
    'Painter',
    'Welder',
    'HVAC Technician',
    'Tiler',
    'Roofer',
    'Steel Fixer',
    'Scaffold Builder',
    'General Laborer',
  ],
  'Hospitality & Food': [
    'Chef',
    'Cook',
    'Kitchen Helper',
    'Barista',
    'Waiter / Waitress',
    'Bartender',
    'Baker',
    'Pastry Chef',
    'Restaurant Manager',
    'Housekeeping Staff',
  ],
  'Transport & Delivery': [
    'Heavy Vehicle Driver',
    'Delivery Rider',
    'Truck Driver',
    'Taxi Driver',
    'Bus Driver',
    'Courier',
    'Forklift Operator',
    'Logistics Coordinator',
  ],
  'Home & Personal Services': [
    'Cleaner',
    'Housekeeper',
    'Nanny',
    'Elderly Caregiver',
    'Gardener',
    'Laundry Worker',
    'Pest Control Technician',
    'Handyman',
  ],
  'Business & Admin': [
    'Accountant',
    'Bookkeeper',
    'Office Assistant',
    'Receptionist',
    'HR Officer',
    'Sales Executive',
    'Marketing Officer',
    'Customer Support Agent',
    'Project Manager',
    'Administrative Officer',
  ],
  'Education & Training': [
    'School Teacher',
    'Private Tutor',
    'Language Instructor',
    'Music Teacher',
    'Driving Instructor',
    'Vocational Trainer',
    'Teaching Assistant',
  ],
  'Health & Care': [
    'Nurse',
    'Caregiver',
    'Pharmacy Assistant',
    'Lab Technician',
    'Physiotherapy Assistant',
    'Medical Officer',
    'Community Health Worker',
  ],
  'Events & Media': [
    'Event Planner',
    'Event Security',
    'Photographer',
    'Videographer',
    'Sound Technician',
    'DJ',
    'MC / Host',
    'Stage Hand',
    'Journalist',
    'Content Writer',
  ],
  'Beauty & Wellness': [
    'Hair Stylist',
    'Barber',
    'Makeup Artist',
    'Beautician',
    'Nail Technician',
    'Massage Therapist',
    'Fitness Trainer',
    'Yoga Instructor',
  ],
  'Security & Safety': [
    'Security Guard',
    'CCTV Operator',
    'Safety Officer',
    'Bouncer',
    'Fire Safety Technician',
  ],
  'Agriculture & Farming': [
    'Farm Worker',
    'Landscaper',
    'Animal Caretaker',
    'Greenhouse Worker',
    'Harvest Worker',
    'Irrigation Technician',
  ],
  'Retail & Sales': [
    'Shop Assistant',
    'Cashier',
    'Store Keeper',
    'Merchandiser',
    'Retail Manager',
    'Sales Promoter',
  ],
};

IconData jobCategoryIcon(String category) =>
    jobCategoryIcons[category] ?? Icons.work_outline;

int get jobTypeCount =>
    jobCatalog.values.fold(0, (sum, list) => sum + list.length);

/// Case-insensitive search across titles and categories. An empty query
/// returns every job type in catalog order.
List<JobTypeSelection> searchJobTypes(String query) {
  final q = query.trim().toLowerCase();
  final results = <JobTypeSelection>[];
  for (final entry in jobCatalog.entries) {
    final categoryMatches = entry.key.toLowerCase().contains(q);
    for (final title in entry.value) {
      if (q.isEmpty || categoryMatches || title.toLowerCase().contains(q)) {
        results.add(JobTypeSelection(title, entry.key));
      }
    }
  }
  return results;
}