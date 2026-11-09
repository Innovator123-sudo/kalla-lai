import 'package:flutter/material.dart';
import 'package:kalla_lai/core/theme/kalla_lai_theme.dart';
import 'package:kalla_lai/features/hiring/domain/job_catalog.dart';

/// Full-screen searchable list of 100+ job types. Pops with the chosen
/// [JobTypeSelection], or null if the user backs out.
class JobTypePickerScreen extends StatefulWidget {
  const JobTypePickerScreen({super.key, this.initialTitle});

  final String? initialTitle;

  @override
  State<JobTypePickerScreen> createState() => _JobTypePickerScreenState();
}

class _JobTypePickerScreenState extends State<JobTypePickerScreen> {
  late final TextEditingController _search;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _search = TextEditingController();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = searchJobTypes(_query);
    return Scaffold(
      appBar: AppBar(title: const Text('Choose a job type')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _search,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search $jobTypeCount job types…',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          if (_query.trim().length >= 2)
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE0E7FF),
                child: Icon(Icons.edit_outlined, color: KallaLaiColors.indigo, size: 20),
              ),
              title: Text('Use “${_query.trim()}” as the job title'),
              subtitle: const Text('Custom title · category “Other”'),
              onTap: () => Navigator.of(context).pop(
                JobTypeSelection(_query.trim(), 'Other'),
              ),
            ),
          Expanded(
            child: results.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.search_off, size: 40, color: KallaLaiColors.muted),
                          const SizedBox(height: 12),
                          Text(
                            'No match for “$_query”. You can type a custom job title on the form.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: KallaLaiColors.muted),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 20),
                    itemCount: results.length,
                    itemBuilder: (context, index) {
                      final item = results[index];
                      final selected = item.title == widget.initialTitle;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: KallaLaiColors.indigo.withValues(alpha: 0.1),
                          child: Icon(jobCategoryIcon(item.category), color: KallaLaiColors.indigo, size: 20),
                        ),
                        title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(item.category),
                        trailing: selected ? const Icon(Icons.check_circle, color: KallaLaiColors.indigo) : null,
                        onTap: () => Navigator.of(context).pop(item),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}