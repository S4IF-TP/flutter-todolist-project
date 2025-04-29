import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart'; // For date formatting

ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
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
          home: const TodoListScreen(),
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

// Add these helper methods to your state class:
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
  final CollectionReference _todosCollection = FirebaseFirestore.instance
      .collection('todos');
  late int _hoveredIndex = -1; // For hover effect (optional)

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
        });
        setState(() {
          _dueDate = null;
          _hasDueDate = false;
        });
        _textFieldController.clear();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Task updated successfully')),
          );
        }
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
      });
      setState(() {
        _dueDate = null;
        _hasDueDate = false;
      });
      _textFieldController.clear();
      if (mounted) {
        Navigator.of(context).maybePop();
      }
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
      firstDate: DateTime.now(),
      lastDate: DateTime(DateTime.now().year + 2),
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
      // Store the task before deleting for potential undo
      final deletedTask = todoDoc.data() as Map<String, dynamic>;
      await _todosCollection.doc(todoDoc.id).delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Task deleted'),
            action: SnackBarAction(
              label: 'UNDO',
              onPressed: () async {
                await _todosCollection.doc(todoDoc.id).set(deletedTask);
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

  DateTime? _dueDate;
  bool _hasDueDate = false;

  Future<void> _displayAddDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Add New Task',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
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
                Row(
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
                          setState(() {
                            _dueDate = date;
                            _hasDueDate = true;
                          });
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _hasDueDate
                          ? 'Due: ${DateFormat('MMM dd, yyyy').format(_dueDate!)}'
                          : 'No due date',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (_hasDueDate)
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          setState(() {
                            _dueDate = null;
                            _hasDueDate = false;
                          });
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor:
                            Theme.of(context).colorScheme.secondary,
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
                            Theme.of(context).colorScheme.primaryContainer,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Add Task'),
                      onPressed: () => _addTodoItem(_textFieldController.text),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showEditDialog(DocumentSnapshot todoDoc) async {
    final data = todoDoc.data() as Map<String, dynamic>;
    _textFieldController.text = data['title'] ?? '';
    setState(() {
      _dueDate = data['dueDate']?.toDate();
      _hasDueDate = data['dueDate'] != null;
    });
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Edit Task',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor:
                            Theme.of(context).colorScheme.secondary,
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
                            Theme.of(context).colorScheme.primaryContainer,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Save Changes'),
                      onPressed: () {
                        _updateTodoItem(todoDoc, _textFieldController.text);
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
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
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            _todosCollection.orderBy('dueDate', descending: false).snapshots(),

        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
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
                  Text(
                    '${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            );
          }
          final docs = snapshot.data?.docs;
          if (docs == null || docs.isEmpty) {
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
                    'No tasks yet!',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap the + button to add your first task',
                    style: Theme.of(context).textTheme.bodyMedium,
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
              final data = doc.data() as Map<String, dynamic>?;
              final title = data?['title'] as String? ?? '';
              final isDone = data?['isDone'] as bool? ?? false;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Dismissible(
                  key: ValueKey(doc.id),
                  background: Container(
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  confirmDismiss: (direction) async {
                    return await _showDeleteConfirmation(doc) ?? false;
                  },
                  onDismissed: (direction) => _deleteTodoItem(doc),
                  child: Slidable(
                    key: ValueKey(doc.id),
                    endActionPane: ActionPane(
                      motion: const ScrollMotion(),
                      children: [
                        SlidableAction(
                          onPressed: (context) => _showDeleteConfirmation(doc),
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          icon: Icons.delete,
                          label: 'Delete',
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ],
                    ),
                    child: Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        leading: Transform.scale(
                          scale: 1.3,
                          child: Checkbox(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            value: isDone,
                            onChanged: (_) => _toggleTodoStatus(doc),
                          ),
                        ),
                        title: Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            decoration:
                                isDone
                                    ? TextDecoration.lineThrough
                                    : TextDecoration.none,
                            color:
                                isDone
                                    ? Theme.of(context).disabledColor
                                    : Theme.of(
                                      context,
                                    ).textTheme.titleMedium?.color,
                          ),
                        ),
                        // Add this as a subtitle in your ListTile
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Display UpdatedAt if it exists
                            if (data?['updatedAt'] != null)
                              Padding(
                                // Add some padding below UpdatedAt if DueDate is also present
                                padding: EdgeInsets.only(
                                  bottom: data?['dueDate'] != null ? 4.0 : 0.0,
                                ),
                                child: Text(
                                  'Updated: ${DateFormat('MMM dd, hh:mm a').format((data!['updatedAt'] as Timestamp).toDate())}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            // Display DueDate if it exists
                            if (data?['dueDate'] != null)
                              Container(
                                // margin: const EdgeInsets.only(top: 4), // Only needed if UpdatedAt is NOT present
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 3,
                                ), // Slightly smaller padding
                                decoration: BoxDecoration(
                                  // Use the helper function for color
                                  color: _getDueDateColor(
                                    context,
                                    (data!['dueDate'] as Timestamp).toDate(),
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    8,
                                  ), // Match card radius better
                                ),
                                child: Text(
                                  // Use the helper function for text
                                  _getDueDateText(
                                    (data!['dueDate'] as Timestamp).toDate(),
                                  ),
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodySmall?.copyWith(
                                    // Adjust color based on theme brightness for better contrast
                                    color:
                                        Theme.of(context).brightness ==
                                                Brightness.light
                                            ? Colors
                                                .black87 // Or specific color for light theme
                                            : Colors
                                                .white, // Or specific color for dark theme
                                    fontWeight:
                                        FontWeight
                                            .w500, // Make it slightly bolder
                                  ),
                                ),
                              ),
                          ],
                        ),
                        // Replace your existing trailing with this:
                        // Replace your existing trailing with this:
                        // Replace your existing trailing with this:
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min, // Keep this
                          children: [
                            // Status Icon (Keep as is)
                            Icon(
                              isDone
                                  ? Icons.check_circle
                                  : Icons.circle_outlined,
                              color:
                                  isDone
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).disabledColor,
                            ),
                            const SizedBox(width: 8), // Keep spacing
                            // --- EDIT BUTTON ---
                            // Use IconButton instead of Material/InkWell
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              color: Colors.blue, // Set color directly
                              tooltip: 'Edit Task', // Good for accessibility
                              onPressed: () => _showEditDialog(doc),
                              // Optional: Adjust splash radius if needed
                              // splashRadius: 20,
                              // Optional: Add constraints if default padding is too large
                              // constraints: BoxConstraints(),
                              // padding: EdgeInsets.zero, // Remove padding if needed
                            ),
                            // --- DELETE BUTTON ---
                            // Use IconButton instead of Material/InkWell
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              color: Colors.redAccent, // Set color directly
                              tooltip: 'Delete Task', // Good for accessibility
                              onPressed: () => _showDeleteConfirmation(doc),
                              // Optional: Adjust splash radius if needed
                              // splashRadius: 20,
                              // Optional: Add constraints if default padding is too large
                              // constraints: BoxConstraints(),
                              // padding: EdgeInsets.zero, // Remove padding if needed
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
