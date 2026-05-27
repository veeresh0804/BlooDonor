import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../config/theme/app_theme.dart';
import '../logic/hospital_provider.dart';

class LeadsScreen extends StatelessWidget {
  final String requestId;
  final String bloodGroup;

  const LeadsScreen({
    super.key,
    required this.requestId,
    required this.bloodGroup,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Leads — $bloodGroup')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _loadLeads(context),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final leads = snapshot.data ?? [];

          if (leads.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 64,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No leads yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Community SOS is active. Leads will appear here when donors refer someone.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: leads.length,
            itemBuilder: (context, index) {
              final lead = leads[index];
              return _LeadCard(lead: lead);
            },
          );
        },
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _loadLeads(BuildContext context) async {
    return await context.read<HospitalProvider>().getLeads(requestId);
  }
}

class _LeadCard extends StatelessWidget {
  final Map<String, dynamic> lead;

  const _LeadCard({required this.lead});

  @override
  Widget build(BuildContext context) {
    final name = lead['referred_name'] ?? 'Unknown';
    final phone = lead['referred_phone'] ?? '';
    final status = lead['status'] ?? 'pending';
    final statusColor = _statusColor(status);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.15),
          child: Icon(_statusIcon(status), color: statusColor, size: 20),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(phone),
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                status.toUpperCase(),
                style: TextStyle(
                  color: statusColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.phone, color: AppColors.eligible),
          onPressed: () async {
            final url = Uri.parse('tel:$phone');
            if (await canLaunchUrl(url)) {
              await launchUrl(url);
            }
          },
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    return switch (status) {
      'pending' => AppColors.urgent,
      'contacted' => AppColors.normal,
      'donated' => AppColors.eligible,
      'not_available' => AppColors.cooldown,
      _ => AppColors.textSecondary,
    };
  }

  IconData _statusIcon(String status) {
    return switch (status) {
      'pending' => Icons.hourglass_empty,
      'contacted' => Icons.phone,
      'donated' => Icons.check_circle,
      'not_available' => Icons.cancel,
      _ => Icons.info,
    };
  }
}
