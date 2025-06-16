// MCP UI DSL v1.0 Demo Definitions (Latest Flat Structure)

// State and Bindings Demo
final Map<String, dynamic> stateAndBindingsDemo = {
  'type': 'page',
  'content': {
    'type': 'container',
    'padding': {'all': 16},
    'child': {
      'type': 'column',
      'children': [
        {
          'type': 'text',
          'value': 'State & Bindings Demo',
          'style': {'fontSize': 24, 'fontWeight': 'bold'},
        },
        {
          'type': 'text',
          'value': '{{message}}',
          'style': {'fontSize': 20, 'fontWeight': 'bold'},
        },
        {
          'type': 'text',
          'value': 'Counter: {{counter}}',
          'style': {'fontSize': 18},
        },
        {
          'type': 'row',
          'mainAxisAlignment': 'center',
          'children': [
            {
              'type': 'button',
              'label': '-',
              'style': 'elevated',
              'onTap': {
                'type': 'tool',
                'tool': 'decrement',
                'args': {},
                'onSuccess': {
                  'type': 'state',
                  'action': 'decrement',
                  'binding': 'counter'
                }
              },
            },
            {
              'type': 'button',
              'label': '+',
              'style': 'elevated',
              'onTap': {
                'type': 'tool',
                'tool': 'increment',
                'args': {},
                'onSuccess': {
                  'type': 'state',
                  'action': 'increment',
                  'binding': 'counter'
                }
              },
            },
            {
              'type': 'button',
              'label': 'Reset',
              'style': 'outlined',
              'onTap': {
                'type': 'tool',
                'tool': 'reset',
                'args': {},
                'onSuccess': {
                  'type': 'state',
                  'action': 'set',
                  'binding': 'counter',
                  'value': 0
                }
              },
            },
          ],
        },
        {
          'type': 'text',
          'value': 'Computed Properties:',
          'style': {'fontSize': 18, 'fontWeight': 'bold'},
        },
        {
          'type': 'text',
          'value': 'Double: {{doubleCounter}}',
          'style': {'fontSize': 16},
        },
        {
          'type': 'text',
          'value': 'Is Positive: {{isPositive}}',
          'style': {'fontSize': 16},
        },
      ],
    },
  },
  'runtime': {
    'services': {
      'state': {
        'initialState': {
          'counter': 0,
          'message': 'Hello from State!',
          'doubleCounter': 0,
          'isPositive': false,
        },
      },
    },
  },
};

// Page Type Demo
final Map<String, dynamic> pageTypeDemo = {
  'type': 'page',
  'content': {
    'type': 'center',
    'child': {
      'type': 'column',
      'mainAxisAlignment': 'center',
      'children': [
        {
          'type': 'text',
          'value': 'This is a simple page type UI',
          'style': {'fontSize': 24, 'fontWeight': 'bold'},
        },
        {
          'type': 'text',
          'value': 'Perfect for single-screen interfaces',
          'style': {'fontSize': 16},
        },
        {
          'type': 'button',
          'label': 'Click Me',
          'style': 'elevated',
          'onTap': {
            'type': 'tool',
            'tool': 'showMessage',
            'args': {'message': 'Hello from page type!'},
          },
        },
      ],
    },
  },
};

// Navigation Demo
final Map<String, dynamic> navigationDemo = {
  'type': 'page',
  'content': {
    'type': 'center',
    'child': {
      'type': 'column',
      'mainAxisAlignment': 'center',
      'children': [
        {
          'type': 'text',
          'value': 'Navigation patterns demo',
          'style': {'fontSize': 24, 'fontWeight': 'bold'},
        },
        {
          'type': 'text',
          'value': 'Tabs, Drawer, and Bottom Navigation',
          'style': {'fontSize': 16},
        },
      ],
    },
  },
};

// Background Services Demo
final Map<String, dynamic> backgroundServicesDemo = {
  'type': 'page',
  'content': {
    'type': 'container',
    'padding': {'all': 16},
    'child': {
      'type': 'column',
      'children': [
        {
          'type': 'text',
          'value': 'Background Services Types',
          'style': {'fontSize': 24, 'fontWeight': 'bold'},
        },
        {
          'type': 'card',
          'margin': {'all': 8},
          'child': {
            'type': 'container',
            'padding': {'all': 16},
            'child': {
              'type': 'row',
              'children': [
                {
                  'type': 'expanded',
                  'child': {
                    'type': 'column',
                    'crossAxisAlignment': 'start',
                    'children': [
                      {
                        'type': 'text',
                        'value': 'Periodic Service',
                        'style': {'fontSize': 16, 'fontWeight': 'bold'},
                      },
                      {
                        'type': 'text',
                        'value': 'Runs every 30 seconds',
                        'style': {'fontSize': 14},
                      },
                    ],
                  },
                },
                {
                  'type': 'button',
                  'label': 'Start',
                  'style': 'elevated',
                  'onTap': {
                    'type': 'tool',
                    'tool': 'startPeriodicService',
                    'args': {},
                  },
                },
              ],
            },
          },
        },
        {
          'type': 'card',
          'margin': {'all': 8},
          'child': {
            'type': 'container',
            'padding': {'all': 16},
            'child': {
              'type': 'row',
              'children': [
                {
                  'type': 'expanded',
                  'child': {
                    'type': 'column',
                    'crossAxisAlignment': 'start',
                    'children': [
                      {
                        'type': 'text',
                        'value': 'Scheduled Service',
                        'style': {'fontSize': 16, 'fontWeight': 'bold'},
                      },
                      {
                        'type': 'text',
                        'value': 'Runs at specific times',
                        'style': {'fontSize': 14},
                      },
                    ],
                  },
                },
                {
                  'type': 'button',
                  'label': 'Schedule',
                  'style': 'elevated',
                  'onTap': {
                    'type': 'tool',
                    'tool': 'scheduleService',
                    'args': {},
                  },
                },
              ],
            },
          },
        },
        {
          'type': 'card',
          'margin': {'all': 8},
          'child': {
            'type': 'container',
            'padding': {'all': 16},
            'child': {
              'type': 'row',
              'children': [
                {
                  'type': 'expanded',
                  'child': {
                    'type': 'column',
                    'crossAxisAlignment': 'start',
                    'children': [
                      {
                        'type': 'text',
                        'value': 'Event-based Service',
                        'style': {'fontSize': 16, 'fontWeight': 'bold'},
                      },
                      {
                        'type': 'text',
                        'value': 'Triggered by events',
                        'style': {'fontSize': 14},
                      },
                    ],
                  },
                },
                {
                  'type': 'button',
                  'label': 'Enable',
                  'style': 'elevated',
                  'onTap': {
                    'type': 'tool',
                    'tool': 'enableEventService',
                    'args': {},
                  },
                },
              ],
            },
          },
        },
      ],
    },
  },
  'runtime': {
    'services': {
      'backgroundServices': {
        'dataSync': {
          'type': 'periodic',
          'interval': 30000,
          'tool': 'syncData',
          'constraints': {
            'networkRequired': true,
            'batteryOptimized': true,
          },
        },
        'backup': {
          'type': 'scheduled',
          'schedule': '0 2 * * *', // Daily at 2 AM
          'tool': 'performBackup',
        },
        'analytics': {
          'type': 'event',
          'events': ['user_action', 'page_view'],
          'tool': 'sendAnalytics',
        },
      },
    },
  },
};

// Notification System Demo
final Map<String, dynamic> notificationSystemDemo = {
  'type': 'page',
  'content': {
    'type': 'container',
    'padding': {'all': 16},
    'child': {
      'type': 'column',
      'children': [
        {
          'type': 'text',
          'value': 'Real-time Notifications',
          'style': {'fontSize': 24, 'fontWeight': 'bold'},
        },
        {
          'type': 'text',
          'value': 'Active Notifications: {{notifications.length}}',
          'style': {'fontSize': 18},
        },
        {
          'type': 'row',
          'mainAxisAlignment': 'spaceEvenly',
          'children': [
            {
              'type': 'button',
              'label': 'Info',
              'style': 'elevated',
              'onTap': {
                'type': 'tool',
                'tool': 'addNotification',
                'args': {'title': 'Info', 'message': 'This is an info notification'},
              },
            },
            {
              'type': 'button',
              'label': 'Warning',
              'style': 'elevated',
              'onTap': {
                'type': 'tool',
                'tool': 'addNotification',
                'args': {'title': 'Warning', 'message': 'This is a warning notification'},
              },
            },
            {
              'type': 'button',
              'label': 'Error',
              'style': 'elevated',
              'onTap': {
                'type': 'tool',
                'tool': 'addNotification',
                'args': {'title': 'Error', 'message': 'This is an error notification'},
              },
            },
          ],
        },
        {
          'type': 'text',
          'value': 'Notification Channels:',
          'style': {'fontSize': 18, 'fontWeight': 'bold'},
        },
        {
          'type': 'text',
          'value': '• General (Default importance)',
        },
        {
          'type': 'text',
          'value': '• Alerts (High importance)',
        },
        {
          'type': 'text',
          'value': '• Updates (Low importance)',
        },
      ],
    },
  },
  'runtime': {
    'services': {
      'state': {
        'initialState': {
          'notifications': [],
          'channels': ['general', 'alerts', 'updates'],
          'notificationCount': 0,
        },
      },
      'notifications': {
        'channels': [
          {'id': 'general', 'name': 'General', 'importance': 'default'},
          {'id': 'alerts', 'name': 'Alerts', 'importance': 'high'},
          {'id': 'updates', 'name': 'Updates', 'importance': 'low'},
        ],
      },
    },
  },
};

// Tool Integration Demo
final Map<String, dynamic> toolIntegrationDemo = {
  'type': 'page',
  'content': {
    'type': 'container',
    'padding': {'all': 16},
    'child': {
      'type': 'column',
      'children': [
        {
          'type': 'text',
          'value': 'MCP Tool Integration',
          'style': {'fontSize': 24, 'fontWeight': 'bold'},
        },
        {
          'type': 'text',
          'value': 'Platform: {{systemInfo.platform}}',
          'style': {'fontSize': 16},
        },
        {
          'type': 'text',
          'value': 'Runtime: {{systemInfo.runtime}}',
          'style': {'fontSize': 16},
        },
        {
          'type': 'text',
          'value': '{{loading ? "Loading..." : "Ready"}}',
          'style': {'fontSize': 16, 'fontWeight': 'bold'},
        },
        {
          'type': 'row',
          'mainAxisAlignment': 'spaceEvenly',
          'children': [
            {
              'type': 'button',
              'label': 'System Info',
              'style': 'elevated',
              'onTap': {
                'type': 'tool',
                'tool': 'getSystemInfo',
                'args': {},
              },
            },
            {
              'type': 'button',
              'label': 'Background Task',
              'style': 'elevated',
              'onTap': {
                'type': 'tool',
                'tool': 'startBackgroundTask',
                'args': {},
              },
            },
          ],
        },
        {
          'type': 'button',
          'label': 'Refresh Data',
          'style': 'elevated',
          'onTap': {
            'type': 'tool',
            'tool': 'refreshData',
            'args': {},
          },
        },
        {
          'type': 'text',
          'value': 'Available MCP Tools:',
          'style': {'fontSize': 18, 'fontWeight': 'bold'},
        },
        {
          'type': 'text',
          'value': '• getSystemInfo - Get system information',
        },
        {
          'type': 'text',
          'value': '• startBackgroundTask - Start background task',
        },
        {
          'type': 'text',
          'value': '• refreshData - Refresh application data',
        },
        {
          'type': 'text',
          'value': 'Total calls: {{toolCalls.length}}',
          'style': {'fontSize': 16},
        },
      ],
    },
  },
  'runtime': {
    'services': {
      'state': {
        'initialState': {
          'toolCalls': [],
          'backgroundTasks': [],
          'systemInfo': {
            'platform': 'flutter',
            'version': '3.10.0',
            'runtime': 'MCP UI Runtime 1.0',
          },
          'loading': false,
          'lastRefresh': null,
        },
      },
    },
  },
};

// Lifecycle Management Demo
final Map<String, dynamic> lifecycleManagementDemo = {
  'type': 'page',
  'content': {
    'type': 'container',
    'padding': {'all': 16},
    'child': {
      'type': 'column',
      'crossAxisAlignment': 'start',
      'children': [
        {
          'type': 'text',
          'value': 'Runtime Lifecycle Demo',
          'style': {'fontSize': 24, 'fontWeight': 'bold'},
        },
        {
          'type': 'text',
          'value': 'Status: {{status}}',
          'style': {'fontSize': 18},
        },
        {
          'type': 'text',
          'value': 'Initialized: {{initTime ?? "Not yet"}}',
          'style': {'fontSize': 16},
        },
        {
          'type': 'text',
          'value': 'Ready: {{readyTime ?? "Not yet"}}',
          'style': {'fontSize': 16},
        },
        {
          'type': 'button',
          'label': 'Toggle Status',
          'style': 'elevated',
          'onTap': {
            'type': 'tool',
            'tool': 'toggleStatus',
            'args': {},
          },
        },
      ],
    },
  },
  'runtime': {
    'services': {
      'state': {
        'initialState': {
          'status': 'Initializing',
          'initTime': null,
          'readyTime': null,
          'counter': 0,
        },
      },
      'notifications': {
        'channels': [
          {'id': 'lifecycle', 'name': 'Lifecycle Events', 'importance': 'high'},
        ],
      },
    },
  },
};

// Application Type Demo - shows application-level features as a page
final Map<String, dynamic> applicationTypeDemo = {
  'type': 'page',
  'content': {
    'type': 'container',
    'padding': {'all': 16},
    'child': {
      'type': 'column',
      'children': [
        {
          'type': 'text',
          'value': 'Application Type Demo',
          'style': {'fontSize': 24, 'fontWeight': 'bold'},
        },
        {
          'type': 'text',
          'value': 'This demo shows application-level features:',
          'style': {'fontSize': 16},
        },
        {
          'type': 'text',
          'value': 'Current User: {{currentUser}}',
          'style': {'fontSize': 18},
        },
        {
          'type': 'text',
          'value': 'Logged In: {{isLoggedIn}}',
          'style': {'fontSize': 16},
        },
        {
          'type': 'text',
          'value': 'Theme Mode: {{themeMode}}',
          'style': {'fontSize': 16},
        },
        {
          'type': 'text',
          'value': 'App Status: {{appStatus}}',
          'style': {'fontSize': 16},
        },
        {
          'type': 'button',
          'label': 'Toggle Status',
          'style': 'elevated',
          'onTap': {
            'type': 'tool',
            'tool': 'toggleStatus',
            'args': {},
          },
        },
        {
          'type': 'text',
          'value': 'Application Features:',
          'style': {'fontSize': 18, 'fontWeight': 'bold'},
        },
        {
          'type': 'text',
          'value': '• Multi-page Navigation',
        },
        {
          'type': 'text',
          'value': '• Global State Management',
        },
        {
          'type': 'text',
          'value': '• Route Parameters',
        },
        {
          'type': 'text',
          'value': '• Background Services',
        },
      ],
    },
  },
  'runtime': {
    'services': {
      'state': {
        'initialState': {
          'currentUser': 'Demo User',
          'isLoggedIn': true,
          'themeMode': 'system',
          'appStatus': 'ready',
        },
      },
    },
  },
};