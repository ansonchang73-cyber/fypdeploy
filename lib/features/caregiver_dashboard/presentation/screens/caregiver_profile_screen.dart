ListView.separated(
  shrinkWrap: true, 
  physics: const NeverScrollableScrollPhysics(), 
  padding: EdgeInsets.zero, 
  itemCount: visibleAppointments.length,
  separatorBuilder: (context, index) => const SizedBox(height: 12),
  itemBuilder: (context, index) {
    final Appointment appointment = visibleAppointments[index];
    
    // Ensure you have a method to format the file name, exactly like the patient profile does
    final String fileName = _appointmentRecordFileName(appointment.dateTime);
    
    return GlassPanel(
      padding: const EdgeInsets.all(16),
      borderRadius: 16,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
            child: Icon(LucideIcons.checkCircle, color: Colors.grey.shade400, size: 22)
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appointment.title,
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.grey.shade700)
                ),
                const SizedBox(height: 4),
                Text(
                  'Dr. ${appointment.doctorName} • ${appointment.location}',
                  style: GoogleFonts.inter(color: Colors.grey.shade500, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.clock, size: 14, color: Colors.grey.shade500),
                      const SizedBox(width: 6),
                      Text(DateFormat('EEE, MMM d, yyyy • h:mm a').format(appointment.dateTime), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade500)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    // Place your specific export logic for the caregiver context here
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.fileText, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 8),
                        Flexible(child: Text(fileName, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600), overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: 8),
                        Icon(LucideIcons.downloadCloud, size: 16, color: Colors.grey.shade600)
                      ]
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  },
)