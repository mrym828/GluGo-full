import 'package:flutter/material.dart';

class DevicesDetailScreen extends StatelessWidget {
  const DevicesDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Back button + title
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => Navigator.maybePop(context),
                        ),
                        const Text(
                          'Connected Devices',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        const Text("CGM Linked", style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Current Device card
                    _roundedCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Current Device", style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          ListTile(
                            leading: const Icon(Icons.sensors),
                            title: const Text("Dexcom G7"),
                            subtitle: const Text("Last sync: 5 min ago • Battery 78% • Sensor day 7/10"),
                          ),
                          Row(
                            children: [
                              _actionButton("Sync Now", Colors.lightBlue),
                              const SizedBox(width: 10),
                              _actionButton("Calibrate", Colors.grey.shade300, textColor: Colors.black),
                              const SizedBox(width: 10),
                              _actionButton("Disconnect", Colors.red, textColor: Colors.white),
                            ],
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Data Sources card
                    _roundedCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Data Sources", style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          _listTile("Apple Health", "Connected"),
                          _listTile("Wearables", "Fitbit, Garmin"),
                          _listTile("Bluetooth Permissions", "Allowed"),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Add New Device card
                    _roundedCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Add New Device", style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          _listTile("Scan for Nearby Devices", "Bluetooth"),
                          _listTile("Pair via QR Code", "Dexcom / Libre"),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Help & Support box
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Icon(Icons.help_outline, color: Colors.grey),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "Having trouble connecting your CGM? Ensure Bluetooth is enabled and your sensor is within range. "
                              "Contact support for UAE device availability.",
                              style: TextStyle(fontSize: 13, color: Colors.black87),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 60), // bottom nav space
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Helpers
  static Widget _roundedCard({required Widget child}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }

  static Widget _listTile(String title, String trailingText) {
    return ListTile(
      title: Text(title),
      trailing: Text(trailingText, style: const TextStyle(color: Colors.grey)),
    );
  }

  static Widget _actionButton(String text, Color bg, {Color textColor = Colors.white}) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: textColor,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: () {},
      child: Text(text),
    );
  }
}
