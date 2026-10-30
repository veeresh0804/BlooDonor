import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../config/theme/app_theme.dart';
import '../../../shared/models/blood_request.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/widgets/blood_group_badge.dart';
import '../logic/hospital_provider.dart';
import 'confirm_donation_screen.dart';
import 'leads_screen.dart';

class RequestLiveTracker extends StatefulWidget {
  final BloodRequest request;

  const RequestLiveTracker({super.key, required this.request});

  @override
  State<RequestLiveTracker> createState() => _RequestLiveTrackerState();
}

class _RequestLiveTrackerState extends State<RequestLiveTracker> {
  List<Map<String, dynamic>> _donorResponses = [];
  bool _isLoading = true;
  RealtimeChannel? _channel;

  /// Latest copy of the request. widget.request is a snapshot from when the
  /// screen opened, so units_fulfilled / status would otherwise go stale.
  late BloodRequest _request;

  bool get _isOpen =>
      _request.status == RequestStatus.active ||
      _request.status == RequestStatus.escalating;

  @override
  void initState() {
    super.initState();
    _request = widget.request;
    _refresh();
    _subscribeToUpdates();
  }

  @override
  void dispose() {
    final channel = _channel;
    if (channel != null) {
      // removeChannel (not just unsubscribe) frees the client-side channel.
      Supabase.instance.client.removeChannel(channel);
    }
    super.dispose();
  }

  Future<void> _refresh() async {
    await Future.wait([_loadResponses(), _reloadRequest()]);
  }

  Future<void> _reloadRequest() async {
    try {
      final row = await Supabase.instance.client
          .from('blood_requests')
          .select()
          .eq('id', widget.request.id)
          .maybeSingle();
      if (row == null || !mounted) return;
      setState(() => _request = BloodRequest.fromJson(row));
    } catch (e) {
      debugPrint('Request refresh failed: $e');
    }
  }

  Future<void> _loadResponses() async {
    try {
      final response = await Supabase.instance.client
          .from('donor_responses')
          .select('*, donor_profiles(*)')
          .eq('request_id', widget.request.id)
          .order('created_at', ascending: true);

      if (!mounted) return;
      setState(() {
        _donorResponses = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _subscribeToUpdates() {
    _channel = Supabase.instance.client
        .channel('request-${widget.request.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'donor_responses',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'request_id',
            value: widget.request.id,
          ),
          // Any response change (incl. 'donated') can also change the request's
          // units_fulfilled/status, so refresh both.
          callback: (payload) => _refresh(),
        )
        .subscribe();
  }

  @override
  Widget build(BuildContext context) {
    final request = _request;
    final urgencyColor = switch (request.urgency) {
      Urgency.critical => AppColors.critical,
      Urgency.urgent => AppColors.urgent,
      Urgency.normal => AppColors.normal,
    };

    return Scaffold(
      appBar: AppBar(
        title: Text('Request: ${request.bloodGroupLabel}'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'fulfill') {
                context.read<HospitalProvider>().fulfillRequest(request.id);
                Navigator.pop(context);
              } else if (value == 'cancel') {
                _showCancelDialog(context);
              } else if (value == 'leads') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LeadsScreen(
                      requestId: request.id,
                      bloodGroup: request.bloodGroupLabel,
                    ),
                  ),
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'leads', child: Text('View Leads')),
              if (_isOpen) ...[
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'fulfill',
                  child: Text('Mark Fulfilled'),
                ),
                const PopupMenuItem(
                  value: 'cancel',
                  child: Text('Cancel Request'),
                ),
              ],
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Request header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [urgencyColor, urgencyColor.withValues(alpha: 0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      BloodGroupBadge(
                        bloodGroup: request.bloodGroupLabel,
                        size: 56,
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${request.units} unit${request.units > 1 ? 's' : ''} needed',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            request.urgency.name.toUpperCase(),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 13,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Stats row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _LiveStat(
                        icon: Icons.people,
                        label: 'Notified',
                        value: '${request.donorsNotified}',
                      ),
                      _LiveStat(
                        icon: Icons.check_circle,
                        label: 'Responded',
                        value: '${_donorResponses.length}',
                      ),
                      _LiveStat(
                        icon: Icons.water_drop,
                        label: 'Fulfilled',
                        value: '${request.unitsFulfilled}/${request.units}',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            if (!_isOpen) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.normal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'This request is ${request.status.name}.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Blood drop fill animation
            _BloodDropProgress(
              fulfilled: request.unitsFulfilled,
              total: request.units,
            ),
            const SizedBox(height: 20),

            // Patient story
            if (request.patientStory != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: urgencyColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.favorite, color: urgencyColor, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          "Patient's Story",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: urgencyColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      request.patientStory!,
                      style: const TextStyle(
                        height: 1.5,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Donor responses
            Text(
              'Donor Responses',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_donorResponses.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.hourglass_empty,
                      size: 48,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Waiting for donor responses...',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${request.donorsNotified} donors have been notified',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              )
            else
              ..._donorResponses.map(
                (response) => _DonorResponseCard(
                  canConfirm: _isOpen,
                  response: response,
                  onConfirmDonation: () => _confirmDonation(response),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _confirmDonation(Map<String, dynamic> response) {
    final donorProfile = response['donor_profiles'];
    final donorId = donorProfile?['id'] as String?;
    final bloodGroup = donorProfile?['blood_group'] as String?;
    final rh = donorProfile?['rh_factor'] == 'positive' ? '+' : '-';
    // Donor identity is anonymous to the hospital here; show blood group, never a UUID.
    final donorName =
        bloodGroup != null ? '${bloodGroup.toUpperCase()}$rh donor' : 'Donor';

    if (donorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Donor ID not found')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ConfirmDonationScreen(
          donorId: donorId,
          donorName: donorName,
          bloodGroup: widget.request.bloodGroupLabel,
          requestId: widget.request.id,
        ),
      ),
    );
  }

  void _showCancelDialog(BuildContext context) {
    String? selectedReason;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Cancel Request'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Why are you cancelling?'),
              const SizedBox(height: 16),
              RadioGroup<String>(
                groupValue: selectedReason,
                onChanged: (v) => setDialogState(() => selectedReason = v),
                child: Column(
                  children:
                      [
                            'Found blood elsewhere',
                            'Patient condition changed',
                            'Created by mistake',
                          ]
                          .map(
                            (r) =>
                                RadioListTile<String>(title: Text(r), value: r),
                          )
                          .toList(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Back'),
            ),
            ElevatedButton(
              onPressed: selectedReason == null
                  ? null
                  : () {
                      context.read<HospitalProvider>().cancelRequest(
                        widget.request.id,
                        selectedReason!,
                      );
                      Navigator.pop(context);
                      Navigator.pop(context);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.critical,
              ),
              child: const Text('Cancel Request'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _LiveStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _BloodDropProgress extends StatelessWidget {
  final int fulfilled;
  final int total;

  const _BloodDropProgress({required this.fulfilled, required this.total});

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? fulfilled / total : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.water_drop, color: AppColors.critical),
              const SizedBox(width: 8),
              Text(
                'Blood Collection Progress',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text(
                '$fulfilled / $total units',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              backgroundColor: AppColors.critical.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(
                progress >= 1.0 ? AppColors.eligible : AppColors.critical,
              ),
            ),
          ),
          if (progress >= 1.0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.check_circle,
                  color: AppColors.eligible,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  'Fully Fulfilled!',
                  style: TextStyle(
                    color: AppColors.eligible,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DonorResponseCard extends StatelessWidget {
  final Map<String, dynamic> response;
  final VoidCallback onConfirmDonation;
  final bool canConfirm;

  const _DonorResponseCard({
    required this.canConfirm,
    required this.response,
    required this.onConfirmDonation,
  });

  @override
  Widget build(BuildContext context) {
    final status = response['status'] as String;
    final statusColor = _statusColor(status);
    final statusLabel = _statusLabel(status);
    final donor = response['donor_profiles'];

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.15),
          child: Icon(_statusIcon(status), color: statusColor, size: 20),
        ),
        title: Text(
          donor?['blood_group'] != null
              ? '${(donor['blood_group'] as String).toUpperCase()}${donor['rh_factor'] == 'positive' ? '+' : '-'} donor'
              : 'Donor',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Row(
          children: [
            Text(statusLabel),
            if (response['is_cooldown_override'] == true) ...[
              const SizedBox(width: 8),
              Tooltip(
                message: 'This donor is in a cooldown period.',
                child: Icon(
                  Icons.warning_amber_rounded,
                  size: 16,
                  color: AppColors.urgent,
                ),
              ),
            ],
          ],
        ),
        trailing: canConfirm && (status == 'arrived' || status == 'confirmed')
            ? ElevatedButton(
                onPressed: onConfirmDonation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.eligible,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                child: const Text('Confirm', style: TextStyle(fontSize: 12)),
              )
            : Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
      ),
    );
  }

  Color _statusColor(String status) {
    return switch (status) {
      'notified' => AppColors.textSecondary,
      'accepted' => AppColors.eligible,
      'on_the_way' => AppColors.normal,
      'delayed' => AppColors.urgent,
      'arrived' => AppColors.eligible,
      'confirmed' => AppColors.normal,
      'donated' => AppColors.eligible,
      'stepped_back' => AppColors.cooldown,
      'accident' => AppColors.critical,
      'missed' => AppColors.cooldown,
      _ => AppColors.textSecondary,
    };
  }

  String _statusLabel(String status) {
    return switch (status) {
      'notified' => 'Notified — waiting',
      'accepted' => 'Accepted',
      'on_the_way' => 'On the way',
      'delayed' => 'Delayed',
      'arrived' => 'Arrived at hospital',
      'confirmed' => 'Presence confirmed',
      'donated' => 'Donation complete',
      'stepped_back' => 'Stepped back',
      'accident' => 'Accident reported',
      'missed' => 'No response',
      _ => status,
    };
  }

  IconData _statusIcon(String status) {
    return switch (status) {
      'notified' => Icons.notifications,
      'accepted' => Icons.check,
      'on_the_way' => Icons.directions_car,
      'delayed' => Icons.access_time,
      'arrived' => Icons.location_on,
      'confirmed' => Icons.verified,
      'donated' => Icons.bloodtype,
      'stepped_back' => Icons.arrow_back,
      'accident' => Icons.warning,
      'missed' => Icons.hourglass_empty,
      _ => Icons.info,
    };
  }
}
