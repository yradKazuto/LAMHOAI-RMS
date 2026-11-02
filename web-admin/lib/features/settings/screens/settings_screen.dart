// ... (rest of the file as before)

// Add this into settings_screen.dart:

class _RateHistorySection extends StatefulWidget {
  @override
  _RateHistorySectionState createState() => _RateHistorySectionState();
}

class _RateHistorySectionState extends State<_RateHistorySection> {
  final _svc = RateService();
  List<RateScheduleModel> _schedules = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await _svc.getSchedules();
    if (mounted) setState(() { _schedules = s; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return ListView(
      children: [
        const Text('Rate Schedules', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ..._schedules.map((s) => ListTile(
          title: Text('Year: ${s.year}'),
          subtitle: Text('Status: ${s.isActive ? 'Active' : 'Draft'}'),
          trailing: s.isActive ? null : ElevatedButton(onPressed: () async {
            await _svc.activateSchedule(s.id);
            _load();
          }, child: const Text('Activate')),
        )),
      ],
    );
  }
}
