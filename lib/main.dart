import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart'; // Make sure this file exists and is set up
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:firebase_auth/firebase_auth.dart'; // New for authentication
// Import your auth screen (create this file)
import 'auth_screen.dart';
// Import your auth service (create this file)
import 'auth_service.dart';

ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

// --- START: Priority Constants and Helpers ---
const int priorityLow = 0;
const int priorityMedium = 1;
const int priorityHigh = 2;

Map<int, String> priorityTextMap = {
  priorityLow: 'Low',
  priorityMedium: 'Medium',
  priorityHigh: 'High',
};

// Helper to get priority text
String getPriorityText(int priorityLevel) {
  return priorityTextMap[priorityLevel] ?? 'Medium';
}

// Helper to get priority color
Color getPriorityColor(BuildContext context, int priorityLevel) {
  switch (priorityLevel) {
    case priorityHigh:
      return Colors.red.shade400;
    case priorityLow:
      return Colors.green.shade400;
    case priorityMedium:
    default:
      return Colors.orange.shade300;
  }
}
// --- END: Priority Constants and Helpers ---

// --- START: Filter Enum ---
enum TaskFilter { all, active, completed }
// --- END: Filter Enum ---

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          return const TodoListScreen();
        }

        return const AuthScreen();
      },
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final lightTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.deepPurple,
        brightness: Brightness.light,
        primary: Colors.deepPurple,
        secondary: Colors.purpleAccent,
      ),
      useMaterial3: true,
      textTheme: GoogleFonts.poppinsTextTheme(),
      cardTheme: CardTheme(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(vertical: 4),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );

    final darkTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.deepPurple,
        brightness: Brightness.dark,
        primary: Colors.deepPurple[300],
        secondary: Colors.purpleAccent[200],
      ),
      useMaterial3: true,
      textTheme: GoogleFonts.poppinsTextTheme(
        ThemeData(brightness: Brightness.dark).textTheme,
      ),
      cardTheme: CardTheme(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(vertical: 4),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, currentMode, __) {
        return MaterialApp(
          title: 'Todo Master',
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: currentMode,
          home: const AuthWrapper(), // Changed from TodoListScreen
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

class TodoListScreen extends StatefulWidget {
  const TodoListScreen({super.key});

  @override
  State<TodoListScreen> createState() => _TodoListScreenState();
}

Color _getDueDateColor(BuildContext context, DateTime dueDate) {
  final now = DateTime.now();
  final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
  final today = DateTime(now.year, now.month, now.day);

  if (due.isBefore(today)) {
    return Colors.red.shade400; // Overdue
  } else if (due == today) {
    return Theme.of(context).colorScheme.primaryContainer; // Due today
  } else if (due.difference(today).inDays <= 3) {
    return Colors.orange.shade300; // Due soon
  }
  return Theme.of(context).colorScheme.secondaryContainer; // Future due date
}

String _getDueDateText(DateTime dueDate) {
  final now = DateTime.now();
  final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
  final today = DateTime(now.year, now.month, now.day);
  final diff = due.difference(today).inDays;

  if (due.isBefore(today)) {
    return 'Overdue by ${today.difference(due).inDays} days';
  } else if (due == today) {
    return 'Due today';
  } else if (diff == 1) {
    return 'Due tomorrow';
  } else if (diff <= 7) {
    return 'Due in $diff days';
  }
  return 'Due ${DateFormat('MMM dd').format(dueDate)}';
}

class _TodoListScreenState extends State<TodoListScreen> {
  final TextEditingController _textFieldController = TextEditingController();
  late CollectionReference _todosCollection;
  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // Handle case where user is not logged in (shouldn't happen)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const AuthScreen()),
        );
      });
      return;
    }
    _todosCollection = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('todos');
  }

  DateTime? _dueDate;
  bool _hasDueDate = false;
  int _selectedPriority = priorityMedium;
  TaskFilter _currentFilter = TaskFilter.all;

  Future<bool?> _showDeleteConfirmation(DocumentSnapshot todoDoc) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Task'),
          content: const Text('Are you sure you want to delete this task?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
              onPressed: () {
                _deleteTodoItem(todoDoc);
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateTodoItem(
    DocumentSnapshot todoDoc,
    String newTitle,
  ) async {
    if (newTitle.trim().isNotEmpty) {
      try {
        await _todosCollection.doc(todoDoc.id).update({
          'title': newTitle.trim(),
          'updatedAt': Timestamp.now(),
          'dueDate': _dueDate != null ? Timestamp.fromDate(_dueDate!) : null,
          'priority': _selectedPriority,
        });
        _textFieldController.clear();
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Task updated successfully')),
          );
        }
        setState(() {
          _dueDate = null;
          _hasDueDate = false;
          _selectedPriority = priorityMedium;
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error updating task: $e')));
        }
      }
    }
  }

  Future<void> _addTodoItem(String title) async {
    if (title.trim().isNotEmpty) {
      await _todosCollection.add({
        'title': title.trim(),
        'isDone': false,
        'createdAt': Timestamp.now(),
        'dueDate': _dueDate != null ? Timestamp.fromDate(_dueDate!) : null,
        'priority': _selectedPriority,
      });
      _textFieldController.clear();
      if (mounted) {
        Navigator.of(context).maybePop();
      }
      setState(() {
        _dueDate = null;
        _hasDueDate = false;
        _selectedPriority = priorityMedium;
      });
    }
  }

  Future<void> _toggleTodoStatus(DocumentSnapshot todoDoc) async {
    final currentStatus =
        (todoDoc.data() as Map<String, dynamic>)['isDone'] as bool? ?? false;
    await _todosCollection.doc(todoDoc.id).update({'isDone': !currentStatus});
  }

  Future<DateTime?> _selectDueDate(
    BuildContext context, {
    DateTime? initialDate,
  }) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime(DateTime.now().year + 5),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).colorScheme.primary,
              onPrimary: Colors.white,
              surface: Theme.of(context).colorScheme.surface,
              onSurface: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          child: child!,
        );
      },
    );
    return picked;
  }

  Future<void> _deleteTodoItem(DocumentSnapshot todoDoc) async {
    try {
      final deletedTask = todoDoc.data() as Map<String, dynamic>;
      final String docId = todoDoc.id;
      await _todosCollection.doc(docId).delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Task deleted'),
            action: SnackBarAction(
              label: 'UNDO',
              onPressed: () async {
                await _todosCollection.doc(docId).set(deletedTask);
              },
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting task: $e')));
      }
    }
  }

  List<DropdownMenuItem<int>> _getPriorityDropdownItems() {
    return [
      DropdownMenuItem(
        value: priorityHigh,
        child: Row(
          children: [
            Icon(
              Icons.flag,
              color: getPriorityColor(context, priorityHigh),
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(getPriorityText(priorityHigh)),
          ],
        ),
      ),
      DropdownMenuItem(
        value: priorityMedium,
        child: Row(
          children: [
            Icon(
              Icons.flag,
              color: getPriorityColor(context, priorityMedium),
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(getPriorityText(priorityMedium)),
          ],
        ),
      ),
      DropdownMenuItem(
        value: priorityLow,
        child: Row(
          children: [
            Icon(
              Icons.flag,
              color: getPriorityColor(context, priorityLow),
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(getPriorityText(priorityLow)),
          ],
        ),
      ),
    ];
  }

  Future<void> _displayAddDialog() async {
    _textFieldController.clear();
    _dueDate = null;
    _hasDueDate = false;
    _selectedPriority = priorityMedium;

    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Add New Task',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  StatefulBuilder(
                    builder: (
                      BuildContext context,
                      StateSetter dialogSetState,
                    ) {
                      return DropdownButtonFormField<int>(
                        decoration: InputDecoration(
                          labelText: 'Priority',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 16,
                          ),
                        ),
                        value: _selectedPriority,
                        items: _getPriorityDropdownItems(),
                        onChanged: (value) {
                          if (value != null) {
                            dialogSetState(() {
                              _selectedPriority = value;
                            });
                          }
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _textFieldController,
                    decoration: InputDecoration(
                      hintText: 'What needs to be done?',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                    ),
                    autofocus: true,
                    onSubmitted: (value) => _addTodoItem(value),
                  ),
                  const SizedBox(height: 16),
                  StatefulBuilder(
                    builder: (
                      BuildContext context,
                      StateSetter dialogSetState,
                    ) {
                      return Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.calendar_today,
                              color:
                                  _hasDueDate
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).disabledColor,
                            ),
                            onPressed: () async {
                              final date = await _selectDueDate(
                                context,
                                initialDate: _dueDate,
                              );
                              if (date != null) {
                                dialogSetState(() {
                                  _dueDate = date;
                                  _hasDueDate = true;
                                });
                              }
                            },
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _hasDueDate
                                  ? 'Due: ${DateFormat('MMM dd, yyyy').format(_dueDate!)}'
                                  : 'Set due date',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                          if (_hasDueDate)
                            IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () {
                                dialogSetState(() {
                                  _dueDate = null;
                                  _hasDueDate = false;
                                });
                              },
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.7),
                        ),
                        child: const Text('Cancel'),
                        onPressed: () {
                          _textFieldController.clear();
                          Navigator.of(context).pop();
                        },
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor:
                              Theme.of(context).colorScheme.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        child: const Text('Add Task'),
                        onPressed:
                            () => _addTodoItem(_textFieldController.text),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showEditDialog(DocumentSnapshot todoDoc) async {
    final data = todoDoc.data() as Map<String, dynamic>;
    _textFieldController.text = data['title'] ?? '';
    _dueDate = data['dueDate']?.toDate();
    _hasDueDate = data['dueDate'] != null;
    _selectedPriority = data['priority'] as int? ?? priorityMedium;

    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Edit Task',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  StatefulBuilder(
                    builder: (
                      BuildContext context,
                      StateSetter dialogSetState,
                    ) {
                      return DropdownButtonFormField<int>(
                        decoration: InputDecoration(
                          labelText: 'Priority',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 16,
                          ),
                        ),
                        value: _selectedPriority,
                        items: _getPriorityDropdownItems(),
                        onChanged: (value) {
                          if (value != null) {
                            dialogSetState(() {
                              _selectedPriority = value;
                            });
                          }
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _textFieldController,
                    decoration: InputDecoration(
                      hintText: 'Edit your task',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  StatefulBuilder(
                    builder: (
                      BuildContext context,
                      StateSetter dialogSetState,
                    ) {
                      return Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.calendar_today,
                              color:
                                  _hasDueDate
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).disabledColor,
                            ),
                            onPressed: () async {
                              final date = await _selectDueDate(
                                context,
                                initialDate: _dueDate,
                              );
                              if (date != null) {
                                dialogSetState(() {
                                  _dueDate = date;
                                  _hasDueDate = true;
                                });
                              }
                            },
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _hasDueDate
                                  ? 'Due: ${DateFormat('MMM dd, yyyy').format(_dueDate!)}'
                                  : 'Set due date',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                          if (_hasDueDate)
                            IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () {
                                dialogSetState(() {
                                  _dueDate = null;
                                  _hasDueDate = false;
                                });
                              },
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.7),
                        ),
                        child: const Text('Cancel'),
                        onPressed: () {
                          _textFieldController.clear();
                          Navigator.of(context).pop();
                          setState(() {
                            _dueDate = null;
                            _hasDueDate = false;
                            _selectedPriority = priorityMedium;
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor:
                              Theme.of(context).colorScheme.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        child: const Text('Save Changes'),
                        onPressed: () {
                          _updateTodoItem(todoDoc, _textFieldController.text);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Stream<QuerySnapshot> _getTodosStream() {
    Query query = _todosCollection;

    if (_currentFilter == TaskFilter.active) {
      query = query.where('isDone', isEqualTo: false);
      return query
          .orderBy('priority', descending: true)
          .orderBy('dueDate', descending: false)
          .snapshots();
    } else if (_currentFilter == TaskFilter.completed) {
      query = query.where('isDone', isEqualTo: true);
      return query
          .orderBy('priority', descending: true)
          .orderBy('dueDate', descending: false)
          .snapshots();
    } else {
      // TaskFilter.all
      return query
          .orderBy('isDone', descending: false)
          .orderBy('priority', descending: true)
          .orderBy('dueDate', descending: false)
          .snapshots();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Todo Master'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              themeNotifier.value == ThemeMode.dark
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
            onPressed: () {
              themeNotifier.value =
                  themeNotifier.value == ThemeMode.light
                      ? ThemeMode.dark
                      : ThemeMode.light;
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              if (!mounted) return;
              await AuthService().signOut();
              if (mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const AuthScreen()),
                );
              }
            },
          ),
          PopupMenuButton<TaskFilter>(
            onSelected: (TaskFilter result) {
              setState(() {
                _currentFilter = result;
              });
            },
            itemBuilder:
                (BuildContext context) => <PopupMenuEntry<TaskFilter>>[
                  const PopupMenuItem<TaskFilter>(
                    value: TaskFilter.all,
                    child: Text('All Tasks'),
                  ),
                  const PopupMenuItem<TaskFilter>(
                    value: TaskFilter.active,
                    child: Text('Active Tasks'),
                  ),
                  const PopupMenuItem<TaskFilter>(
                    value: TaskFilter.completed,
                    child: Text('Completed Tasks'),
                  ),
                ],
            icon: const Icon(Icons.filter_list),
            tooltip: "Filter tasks",
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _getTodosStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            print("Firestore Stream Error: ${snapshot.error}");
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading todos',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      '${snapshot.error}\n\nPlease ensure your Firestore rules are correctly set up and check console for index creation links if this is an index-related error.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            );
          }
          final docs = snapshot.data?.docs;
          if (docs == null || docs.isEmpty) {
            String emptyMessageTitle = 'No tasks yet!';
            String emptyMessageSubtitle =
                'Tap the + button to add your first task';
            if (_currentFilter == TaskFilter.active) {
              emptyMessageTitle = 'No active tasks!';
              emptyMessageSubtitle = 'All tasks are done or add a new one.';
            } else if (_currentFilter == TaskFilter.completed) {
              emptyMessageTitle = 'No completed tasks!';
              emptyMessageSubtitle = 'Mark some tasks as done.';
            }
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 64,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    emptyMessageTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    emptyMessageSubtitle,
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data =
                  doc.data()
                      as Map<String, dynamic>?; // data is Map<String, dynamic>?

              final title = data?['title'] as String? ?? '';
              final isDone = data?['isDone'] as bool? ?? false;
              final priority = data?['priority'] as int? ?? priorityMedium;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: 80, // Minimum height for each item
                  ),
                  child: Slidable(
                    key: ValueKey(doc.id),
                    endActionPane: ActionPane(
                      motion: const ScrollMotion(),
                      children: [
                        SlidableAction(
                          onPressed: (context) => _showEditDialog(doc),
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          icon: Icons.edit,
                          label: 'Edit',
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            bottomLeft: Radius.circular(12),
                          ),
                        ),
                        SlidableAction(
                          onPressed: (context) async {
                            bool? confirmed = await _showDeleteConfirmation(
                              doc,
                            );
                            if (confirmed == true) {
                              // Deletion is handled by the dialog's delete button
                            }
                          },
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          icon: Icons.delete,
                          label: 'Delete',
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(12),
                            bottomRight: Radius.circular(12),
                          ),
                        ),
                      ],
                    ),
                    child: Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        constraints: BoxConstraints(
                          minHeight: 72, // Minimum height you want
                        ),
                        child: Row(
                          children: [
                            // Leading (Checkbox + Priority)
                            SizedBox(
                              width: 48,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Checkbox(
                                    value: isDone,
                                    onChanged: (_) => _toggleTodoStatus(doc),
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  Icon(
                                    Icons.flag,
                                    size: 16,
                                    color: getPriorityColor(context, priority),
                                  ),
                                ],
                              ),
                            ),

                            // Main Content
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Title
                                  Text(
                                    title,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium?.copyWith(
                                      decoration:
                                          isDone
                                              ? TextDecoration.lineThrough
                                              : null,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),

                                  // Due Date and other info
                                  if (data?['dueDate'] != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _getDueDateColor(
                                            context,
                                            (data!['dueDate'] as Timestamp)
                                                .toDate(),
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          _getDueDateText(
                                            (data['dueDate'] as Timestamp)
                                                .toDate(),
                                          ),
                                          style:
                                              Theme.of(
                                                context,
                                              ).textTheme.labelSmall,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            // Edit Button
                            IconButton(
                              icon: const Icon(Icons.edit, size: 20),
                              onPressed: () => _showEditDialog(doc),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _displayAddDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Task'),
        elevation: 4,
      ),
    );
  }

  @override
  void dispose() {
    _textFieldController.dispose();
    super.dispose();
  }
}
