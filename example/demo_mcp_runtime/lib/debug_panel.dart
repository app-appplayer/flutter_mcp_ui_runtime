import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';

/// Debug panel widget that shows current state, JSON definition, and runtime info
class DebugPanel extends StatefulWidget {
  final Map<String, dynamic> jsonDefinition;
  final Map<String, dynamic> currentState;
  final Function(String key, dynamic value) onStateChange;
  
  const DebugPanel({
    super.key,
    required this.jsonDefinition,
    required this.currentState,
    required this.onStateChange,
  });

  @override
  State<DebugPanel> createState() => _DebugPanelState();
}

class _DebugPanelState extends State<DebugPanel> with TickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _eventLog = [];
  final TextEditingController _stateKeyController = TextEditingController();
  final TextEditingController _stateValueController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _addEvent('Debug panel initialized');
  }

  @override
  void dispose() {
    _tabController.dispose();
    _stateKeyController.dispose();
    _stateValueController.dispose();
    super.dispose();
  }

  void _addEvent(String event) {
    setState(() {
      _eventLog.insert(0, '${DateTime.now().toString().substring(11, 19)} - $event');
      if (_eventLog.length > 100) {
        _eventLog.removeLast();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 350,
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        border: Border(left: BorderSide(color: Colors.grey.shade700)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade800,
              border: Border(bottom: BorderSide(color: Colors.grey.shade700)),
            ),
            child: Row(
              children: [
                Icon(Icons.bug_report, color: Colors.orange.shade400, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Runtime Debug',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.clear_all, color: Colors.white, size: 18),
                  onPressed: () {
                    setState(() {
                      _eventLog.clear();
                    });
                    _addEvent('Event log cleared');
                  },
                  tooltip: 'Clear logs',
                ),
              ],
            ),
          ),
          
          // Tabs
          Container(
            color: Colors.grey.shade800,
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.blue.shade400,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey.shade400,
              labelStyle: const TextStyle(fontSize: 12),
              tabs: const [
                Tab(text: 'State'),
                Tab(text: 'JSON'),
                Tab(text: 'Events'),
                Tab(text: 'Runtime'),
              ],
            ),
          ),
          
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildStateTab(),
                _buildJsonTab(),
                _buildEventsTab(),
                _buildRuntimeTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStateTab() {
    return Container(
      color: Colors.grey.shade900,
      child: Column(
        children: [
          // State modifier
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade800,
              border: Border(bottom: BorderSide(color: Colors.grey.shade700)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Modify State',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _stateKeyController,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        decoration: const InputDecoration(
                          hintText: 'Key',
                          hintStyle: TextStyle(color: Colors.grey),
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _stateValueController,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        decoration: const InputDecoration(
                          hintText: 'Value',
                          hintStyle: TextStyle(color: Colors.grey),
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        final key = _stateKeyController.text;
                        final valueText = _stateValueController.text;
                        if (key.isNotEmpty && valueText.isNotEmpty) {
                          // Try to parse as different types
                          dynamic value = valueText;
                          if (valueText.toLowerCase() == 'true') {
                            value = true;
                          } else if (valueText.toLowerCase() == 'false') {
                            value = false;
                          } else if (int.tryParse(valueText) != null) {
                            value = int.parse(valueText);
                          } else if (double.tryParse(valueText) != null) {
                            value = double.parse(valueText);
                          }
                          
                          widget.onStateChange(key, value);
                          _addEvent('State updated: $key = $value');
                          _stateKeyController.clear();
                          _stateValueController.clear();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      child: const Text('Set', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Current state display
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Current State',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...widget.currentState.entries.map((entry) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade800,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.key,
                          style: TextStyle(
                            color: Colors.blue.shade300,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          entry.value.toString(),
                          style: const TextStyle(color: Colors.white, fontSize: 11),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJsonTab() {
    return Container(
      color: Colors.grey.shade900,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'JSON Definition',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.copy, color: Colors.white, size: 18),
                onPressed: () {
                  Clipboard.setData(ClipboardData(
                    text: const JsonEncoder.withIndent('  ').convert(widget.jsonDefinition),
                  ));
                  _addEvent('JSON copied to clipboard');
                },
                tooltip: 'Copy JSON',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.grey.shade700),
                ),
                child: Text(
                  const JsonEncoder.withIndent('  ').convert(widget.jsonDefinition),
                  style: const TextStyle(
                    color: Colors.green,
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventsTab() {
    return Container(
      color: Colors.grey.shade900,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Event Log',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: _eventLog.length,
              itemBuilder: (context, index) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade800,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _eventLog[index],
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRuntimeTab() {
    final runtime = widget.jsonDefinition['mcpRuntime']?['runtime'] as Map<String, dynamic>?;
    final services = runtime?['services'] as Map<String, dynamic>?;
    
    return Container(
      color: Colors.grey.shade900,
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          const Text(
            'Runtime Information',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          
          _buildInfoCard('App ID', runtime?['id']?.toString() ?? 'Unknown'),
          _buildInfoCard('Domain', runtime?['domain']?.toString() ?? 'Unknown'),
          _buildInfoCard('Version', runtime?['version']?.toString() ?? '1.0.0'),
          
          const SizedBox(height: 16),
          const Text(
            'Services',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          
          if (services != null) ...[
            ...services.entries.map((entry) {
              return _buildInfoCard(
                entry.key.toUpperCase(),
                'Configured',
                valueColor: Colors.green.shade400,
              );
            }).toList(),
          ] else
            _buildInfoCard('Services', 'None configured'),
          
          const SizedBox(height: 16),
          const Text(
            'Cache Policy',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          
          _buildInfoCard(
            'Cache Enabled',
            runtime?['cachePolicy']?['enabled']?.toString() ?? 'false',
          ),
          _buildInfoCard(
            'Offline Mode',
            runtime?['cachePolicy']?['offlineMode']?.toString() ?? 'disabled',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String label, String value, {Color? valueColor}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.blue.shade300,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.white,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}