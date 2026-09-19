import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const TimetableApp());
}

class TimetableApp extends StatelessWidget {
  const TimetableApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'My Timetable',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF07111F),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF32B9FF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const TimetableHome(),
    );
  }
}

// ======================================================
// CLASS ENTRY
// ======================================================

class ClassEntry {
  final String day;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final String subject;
  final String teacher;
  final String room;

  ClassEntry({
    required this.day,
    required this.startTime,
    required this.endTime,
    required this.subject,
    required this.teacher,
    required this.room,
  });

  // ======================================================
  // CLASS KO MAP MEIN CONVERT KARNA
  // ======================================================

  Map<String, dynamic> toMap() {
    return {
      'day': day,
      'startHour': startTime.hour,
      'startMinute': startTime.minute,
      'endHour': endTime.hour,
      'endMinute': endTime.minute,
      'subject': subject,
      'teacher': teacher,
      'room': room,
    };
  }

  // ======================================================
  // MAP KO CLASS MEIN CONVERT KARNA
  // ======================================================

  factory ClassEntry.fromMap(Map<String, dynamic> map) {
    return ClassEntry(
      day: map['day'] as String,
      startTime: TimeOfDay(
        hour: map['startHour'] as int,
        minute: map['startMinute'] as int,
      ),
      endTime: TimeOfDay(
        hour: map['endHour'] as int,
        minute: map['endMinute'] as int,
      ),
      subject: map['subject'] as String,
      teacher: map['teacher'] as String,
      room: map['room'] as String,
    );
  }
}

// ======================================================
// HOME
// ======================================================

class TimetableHome extends StatefulWidget {
  const TimetableHome({super.key});

  @override
  State<TimetableHome> createState() => _TimetableHomeState();
}

class _TimetableHomeState extends State<TimetableHome> {
  final List<ClassEntry> classes = [];

  ClassEntry? selectedClass;

  // Next class ke exact start time par chalega
  Timer? timeCheckTimer;

  // Local storage mein is naam se data save hoga
  static const String storageKey = 'timetable_classes';

  // Monday to Friday
  final List<String> days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
  ];

  // 30-minute time slots
  final List<String> timeSlots = [
    '8:30',
    '9:00',
    '9:30',
    '10:00',
    '10:30',
    '11:00',
    '11:30',
    '12:00',
    '12:30',
    '1:00',
    '1:30',
    '2:00',
    '2:30',
    '3:00',
    '3:30',
    '4:00',
    '4:30',
  ];

  final double cellWidth = 105;

  final double dayWidth = 110;

  @override
  void initState() {
    super.initState();

    loadClasses();
  }

  @override
  void dispose() {
    timeCheckTimer?.cancel();

    super.dispose();
  }

  // ======================================================
  // LOAD CLASSES
  // ======================================================

  Future<void> loadClasses() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    final String? savedData = prefs.getString(storageKey);

    if (savedData == null) {
      return;
    }

    try {
      final List<dynamic> decodedData = jsonDecode(savedData);

      final List<ClassEntry> loadedClasses = [];

      for (final item in decodedData) {
        loadedClasses.add(ClassEntry.fromMap(Map<String, dynamic>.from(item)));
      }

      // Monday -> Friday
      loadedClasses.sort((a, b) {
        final dayComparison = days
            .indexOf(a.day)
            .compareTo(days.indexOf(b.day));

        if (dayComparison != 0) {
          return dayComparison;
        }

        return timeToMinutes(a.startTime).compareTo(timeToMinutes(b.startTime));
      });

      if (!mounted) {
        return;
      }

      setState(() {
        classes.clear();
        classes.addAll(loadedClasses);
      });

      scheduleNextHighlight();
    } catch (e) {
      debugPrint('Error loading timetable: $e');
    }
  }

  // ======================================================
  // SAVE CLASSES
  // ======================================================

  Future<void> saveClasses() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    final List<Map<String, dynamic>> classData = [];

    for (final entry in classes) {
      classData.add(entry.toMap());
    }

    final String encodedData = jsonEncode(classData);

    await prefs.setString(storageKey, encodedData);
  }

  // ======================================================
  // ADD CLASS
  // ======================================================

  void addClass(ClassEntry newClass) {
    setState(() {
      classes.add(newClass);

      classes.sort((a, b) {
        final dayComparison = days
            .indexOf(a.day)
            .compareTo(days.indexOf(b.day));

        if (dayComparison != 0) {
          return dayComparison;
        }

        return timeToMinutes(a.startTime).compareTo(timeToMinutes(b.startTime));
      });
    });

    saveClasses();

    scheduleNextHighlight();
  }

  // ======================================================
  // DELETE CLASS
  // ======================================================

  void deleteSelectedClass() {
    if (selectedClass == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a class to delete')),
      );

      return;
    }

    setState(() {
      classes.remove(selectedClass);
      selectedClass = null;
    });

    saveClasses();

    scheduleNextHighlight();
  }

  // ======================================================
  // SELECT CLASS
  // ======================================================

  void selectClass(ClassEntry entry) {
    setState(() {
      selectedClass = entry;
    });
  }

  // ======================================================
  // ADD CLASS DIALOG
  // ======================================================

  void showAddClassDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AddClassDialog(days: days, onAdd: addClass);
      },
    );
  }

  // ======================================================
  // TIME TO MINUTES
  // ======================================================

  int timeToMinutes(TimeOfDay time) {
    return time.hour * 60 + time.minute;
  }

  // ======================================================
  // SLOT INDEX
  // ======================================================

  int getSlotIndex(TimeOfDay time) {
    const timetableStart = 8 * 60 + 30;

    final minutes = timeToMinutes(time);

    return ((minutes - timetableStart) / 30).round();
  }

  // ======================================================
  // DAY NAME
  // ======================================================

  String getDayName(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Monday';

      case DateTime.tuesday:
        return 'Tuesday';

      case DateTime.wednesday:
        return 'Wednesday';

      case DateTime.thursday:
        return 'Thursday';

      case DateTime.friday:
        return 'Friday';

      case DateTime.saturday:
        return 'Saturday';

      case DateTime.sunday:
        return 'Sunday';

      default:
        return '';
    }
  }

  // ======================================================
  // UPCOMING CLASS
  // ======================================================

  ClassEntry? getUpcomingClass() {
    if (classes.isEmpty) {
      return null;
    }

    final now = DateTime.now();

    final currentDayNumber = now.weekday;

    final currentMinutes = now.hour * 60 + now.minute;

    // ====================================================
    // TODAY
    // ====================================================

    if (currentDayNumber >= DateTime.monday &&
        currentDayNumber <= DateTime.friday) {
      final today = getDayName(currentDayNumber);

      ClassEntry? nearestClass;

      int nearestStart = 1000000;

      for (final entry in classes) {
        if (entry.day != today) {
          continue;
        }

        final classStart = timeToMinutes(entry.startTime);

        // Class ka start time aa gaya
        // to ye upcoming nahi hai.
        if (classStart <= currentMinutes) {
          continue;
        }

        if (classStart < nearestStart) {
          nearestStart = classStart;
          nearestClass = entry;
        }
      }

      if (nearestClass != null) {
        return nearestClass;
      }
    }

    // ====================================================
    // NEXT WEEKDAY
    // ====================================================

    for (int dayOffset = 1; dayOffset <= 7; dayOffset++) {
      final nextDayNumber = ((currentDayNumber - 1 + dayOffset) % 7) + 1;

      // Saturday aur Sunday skip
      if (nextDayNumber == DateTime.saturday ||
          nextDayNumber == DateTime.sunday) {
        continue;
      }

      final nextDay = getDayName(nextDayNumber);

      ClassEntry? firstClassOfDay;

      int earliestStart = 1000000;

      for (final entry in classes) {
        if (entry.day != nextDay) {
          continue;
        }

        final classStart = timeToMinutes(entry.startTime);

        if (classStart < earliestStart) {
          earliestStart = classStart;
          firstClassOfDay = entry;
        }
      }

      if (firstClassOfDay != null) {
        return firstClassOfDay;
      }
    }

    return null;
  }

  // ======================================================
  // EXACT NEXT HIGHLIGHT TIMER
  // ======================================================

  void scheduleNextHighlight() {
    // Purana timer cancel karo
    timeCheckTimer?.cancel();
    timeCheckTimer = null;

    if (!mounted) {
      return;
    }

    final nextClass = getUpcomingClass();

    // Agar koi upcoming class nahi hai
    if (nextClass == null) {
      return;
    }

    final now = DateTime.now();

    DateTime targetDate;

    // ====================================================
    // AGAR CLASS AAJ HAI
    // ====================================================

    if (now.weekday >= DateTime.monday &&
        now.weekday <= DateTime.friday &&
        nextClass.day == getDayName(now.weekday)) {
      targetDate = DateTime(now.year, now.month, now.day);
    }
    // ====================================================
    // AGAR CLASS FUTURE WEEKDAY PAR HAI
    // ====================================================
    else {
      targetDate = DateTime(now.year, now.month, now.day);

      for (int i = 1; i <= 7; i++) {
        final futureDate = targetDate.add(Duration(days: i));

        if (futureDate.weekday == DateTime.saturday ||
            futureDate.weekday == DateTime.sunday) {
          continue;
        }

        if (getDayName(futureDate.weekday) == nextClass.day) {
          targetDate = futureDate;
          break;
        }
      }
    }

    // ====================================================
    // EXACT START DATETIME
    // ====================================================

    final exactTarget = DateTime(
      targetDate.year,
      targetDate.month,
      targetDate.day,
      nextClass.startTime.hour,
      nextClass.startTime.minute,
    );

    Duration remaining = exactTarget.difference(now);

    // Agar somehow target past ho gaya
    if (remaining.isNegative) {
      remaining = const Duration(milliseconds: 1);
    }

    // ====================================================
    // ONE-SHOT TIMER
    // ====================================================

    timeCheckTimer = Timer(remaining, () {
      if (!mounted) {
        return;
      }

      // Exact class start par UI refresh
      setState(() {});

      // Ab next upcoming class calculate karo
      scheduleNextHighlight();
    });
  }

  // ======================================================
  // MAIN BUILD
  // ======================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background glow
          Positioned(
            top: -150,
            right: -100,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF008CFF).withOpacity(0.18),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF008CFF).withOpacity(0.25),
                    blurRadius: 150,
                    spreadRadius: 60,
                  ),
                ],
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // ==========================================
                  // TOP
                  // ==========================================

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'My Timetable',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          SizedBox(height: 4),

                          Text(
                            'Weekly schedule',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),

                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: showAddClassDialog,
                            icon: const Icon(Icons.add),
                            label: const Text('Add'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1AA9F7),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 13,
                              ),
                              elevation: 8,
                            ),
                          ),

                          const SizedBox(width: 10),

                          ElevatedButton.icon(
                            onPressed: deleteSelectedClass,
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Delete'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent.withOpacity(
                                0.85,
                              ),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 13,
                              ),
                              elevation: 8,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ==========================================
                  // TIMETABLE CONTAINER
                  // ==========================================
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.055),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: const Color(0xFF42C7FF).withOpacity(0.22),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SingleChildScrollView(child: buildTimetable()),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ======================================================
  // TIMETABLE
  // ======================================================

  Widget buildTimetable() {
    final totalWidth = dayWidth + (timeSlots.length * cellWidth);

    return SizedBox(
      width: totalWidth,
      child: Column(
        children: [
          // HEADER
          SizedBox(
            height: 60,
            child: Row(
              children: [
                // Blank top-left
                Container(
                  width: dayWidth,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B2438).withOpacity(0.95),
                    border: Border.all(color: Colors.white.withOpacity(0.10)),
                  ),
                ),

                ...timeSlots.map((time) {
                  return Container(
                    width: cellWidth,
                    height: 60,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B2438).withOpacity(0.95),
                      border: Border.all(color: Colors.white.withOpacity(0.10)),
                    ),
                    child: Text(
                      time,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF63D2FF),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),

          // MONDAY - FRIDAY
          ...days.map((day) {
            return buildDayRow(day);
          }),
        ],
      ),
    );
  }

  // ======================================================
  // DAY ROW
  // ======================================================

  Widget buildDayRow(String day) {
    final totalGridWidth = timeSlots.length * cellWidth;

    return SizedBox(
      height: 90,
      child: Row(
        children: [
          Container(
            width: dayWidth,
            height: 90,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.025),
              border: Border.all(color: Colors.white.withOpacity(0.10)),
            ),
            child: Text(
              day,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ),

          SizedBox(
            width: totalGridWidth,
            height: 90,
            child: Stack(
              children: [
                // EMPTY CELLS
                Row(
                  children: List.generate(timeSlots.length, (index) {
                    return Container(
                      width: cellWidth,
                      height: 90,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.10),
                        ),
                      ),
                    );
                  }),
                ),

                // CLASSES
                ...classes.where((entry) => entry.day == day).map((entry) {
                  return buildClassBlock(entry);
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ======================================================
  // CLASS BLOCK
  // ======================================================

  Widget buildClassBlock(ClassEntry entry) {
    final startIndex = getSlotIndex(entry.startTime);

    final endIndex = getSlotIndex(entry.endTime);

    final numberOfSlots = endIndex - startIndex;

    final left = startIndex * cellWidth;

    final width = numberOfSlots * cellWidth;

    final isSelected = selectedClass == entry;

    final upcomingClass = getUpcomingClass();

    final isUpcoming = upcomingClass == entry;

    return Positioned(
      left: left + 3,
      top: 3,
      width: width - 6,
      height: 84,
      child: GestureDetector(
        onTap: () {
          selectClass(entry);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFFFFA726)
                : isUpcoming
                ? const Color(0xFF00B8D4)
                : const Color(0xFF087DB8).withOpacity(0.85),
            border: Border.all(
              color: isSelected
                  ? Colors.white
                  : isUpcoming
                  ? const Color(0xFF7CFFFF)
                  : const Color(0xFF55D4FF),
              width: isSelected || isUpcoming ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? Colors.orange.withOpacity(0.5)
                    : isUpcoming
                    ? const Color(0xFF00E5FF).withOpacity(0.65)
                    : const Color(0xFF00BFFF).withOpacity(0.25),
                blurRadius: isSelected || isUpcoming ? 16 : 8,
              ),
            ],
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // SUBJECT
                Text(
                  entry.subject.isEmpty ? 'Class' : entry.subject,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 3),

                // ROOM
                if (entry.room.isNotEmpty)
                  Text(
                    'Room ${entry.room}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, color: Colors.white70),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ======================================================
// ADD CLASS DIALOG
// ======================================================

class AddClassDialog extends StatefulWidget {
  final List<String> days;

  final Function(ClassEntry) onAdd;

  const AddClassDialog({super.key, required this.days, required this.onAdd});

  @override
  State<AddClassDialog> createState() => _AddClassDialogState();
}

class _AddClassDialogState extends State<AddClassDialog> {
  String selectedDay = 'Monday';

  TimeOfDay? startTime;

  TimeOfDay? endTime;

  final TextEditingController subjectController = TextEditingController();

  final TextEditingController teacherController = TextEditingController();

  final TextEditingController roomController = TextEditingController();

  // ======================================================
  // START TIME
  // ======================================================

  Future<void> chooseStartTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 30),
    );

    if (selected != null) {
      setState(() {
        startTime = selected;
      });
    }
  }

  // ======================================================
  // END TIME
  // ======================================================

  Future<void> chooseEndTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
    );

    if (selected != null) {
      setState(() {
        endTime = selected;
      });
    }
  }

  // ======================================================
  // FINISH ADDING
  // ======================================================

  void finishAdding() {
    // SUBJECT CHECK
    if (subjectController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter subject name.')),
      );

      return;
    }

    // TIME CHECK
    if (startTime == null || endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select starting and ending time.'),
        ),
      );

      return;
    }

    final startMinutes = startTime!.hour * 60 + startTime!.minute;

    final endMinutes = endTime!.hour * 60 + endTime!.minute;

    // END TIME CHECK
    if (endMinutes <= startMinutes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ending time must be after starting time.'),
        ),
      );

      return;
    }

    // TIMETABLE RANGE
    const timetableStart = 8 * 60 + 30;

    const timetableEnd = 16 * 60 + 30;

    if (startMinutes < timetableStart || endMinutes > timetableEnd) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Class must be between 8:30 AM and 4:30 PM.'),
        ),
      );

      return;
    }

    // 30-MINUTE INTERVAL
    if ((startMinutes - timetableStart) % 30 != 0 ||
        (endMinutes - timetableStart) % 30 != 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please use 30-minute time intervals.')),
      );

      return;
    }

    // CREATE CLASS
    final newClass = ClassEntry(
      day: selectedDay,
      startTime: startTime!,
      endTime: endTime!,
      subject: subjectController.text.trim(),
      teacher: teacherController.text.trim(),
      room: roomController.text.trim(),
    );

    // ADD
    widget.onAdd(newClass);

    // CLOSE
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Class'),

      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // SUBJECT
            TextField(
              controller: subjectController,
              decoration: const InputDecoration(
                labelText: 'Subject Name',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 14),

            // DAY
            DropdownButtonFormField<String>(
              value: selectedDay,
              decoration: const InputDecoration(
                labelText: 'Day',
                border: OutlineInputBorder(),
              ),
              items: widget.days.map((day) {
                return DropdownMenuItem(value: day, child: Text(day));
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    selectedDay = value;
                  });
                }
              },
            ),

            const SizedBox(height: 14),

            // START + END
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: chooseStartTime,
                    child: Text(
                      startTime == null
                          ? 'Start Time'
                          : startTime!.format(context),
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: OutlinedButton(
                    onPressed: chooseEndTime,
                    child: Text(
                      endTime == null ? 'End Time' : endTime!.format(context),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // TEACHER
            TextField(
              controller: teacherController,
              decoration: const InputDecoration(
                labelText: 'Teacher Name',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 14),

            // ROOM
            TextField(
              controller: roomController,
              decoration: const InputDecoration(
                labelText: 'Room No.',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),

      // BUTTONS
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('Cancel'),
        ),

        ElevatedButton(onPressed: finishAdding, child: const Text('Done')),
      ],
    );
  }

  @override
  void dispose() {
    subjectController.dispose();

    teacherController.dispose();

    roomController.dispose();

    super.dispose();
  }
}
