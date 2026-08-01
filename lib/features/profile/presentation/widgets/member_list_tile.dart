// lib/features/profile/presentation/widgets/member_list_tile.dart
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/widgets/glass_panel.dart';
import '../../domain/entities/care_member.dart';

class MemberListTile extends StatelessWidget {
  final CareMember member;

  const MemberListTile({super.key, required this.member});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassPanel(
        padding: const EdgeInsets.all(12),
        borderRadius: 16.0,
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 24,
              backgroundImage: NetworkImage(member.avatarUrl),
              backgroundColor: Colors.grey.shade200,
            ),
            const SizedBox(width: 16),

            // Member Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    member.role,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),

            // Actions
            if (member.type == MemberType.medical)
              IconButton(
                icon: const Icon(LucideIcons.messageSquare, size: 20, color: Colors.blue),
                onPressed: () {},
              )
            else
              IconButton(
                icon: const Icon(LucideIcons.moreVertical, size: 20, color: Colors.grey),
                onPressed: () {},
              ),
          ],
        ),
      ),
    );
  }
}