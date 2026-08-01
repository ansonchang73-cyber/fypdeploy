// lib/features/system_health/domain/usecases/resolve_caregiver_link.dart
import '../entities/caregiver_link_status.dart';

/// A caregiver name is only considered "linked" if it's non-empty and
/// isn't one of the placeholder values the profile feature writes when
/// nothing is actually linked. Extracted from an inline check in
/// `_buildCaregiverSection`.
class ResolveCaregiverLink {
  const ResolveCaregiverLink();

  static const _unlinkedSentinels = {'no caregiver linked', 'none', 'n/a'};

  CaregiverLinkStatus call(String? rawCaregiverName) {
    final String name = rawCaregiverName?.trim() ?? '';
    final bool isLinked =
        name.isNotEmpty && !_unlinkedSentinels.contains(name.toLowerCase());

    return CaregiverLinkStatus(isLinked: isLinked, name: name);
  }
}
