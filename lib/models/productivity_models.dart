import 'package:hive/hive.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// 📋 TODO ITEM
// ═══════════════════════════════════════════════════════════════════════════════

@HiveType(typeId: 20)
class TodoItem extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  bool isCompleted;

  @HiveField(3)
  DateTime createdAt;

  @HiveField(4)
  DateTime? dueDate;

  @HiveField(5)
  int priority; // 0=low, 1=medium, 2=high

  @HiveField(6)
  String? linkedEventId; // Connect todo → event

  @HiveField(7)
  String? linkedDoubtId; // Connect todo → academic doubt

  @HiveField(8)
  String category; // 'general', 'academic', 'personal', 'work'

  TodoItem({
    required this.id,
    required this.title,
    this.isCompleted = false,
    required this.createdAt,
    this.dueDate,
    this.priority = 1,
    this.linkedEventId,
    this.linkedDoubtId,
    this.category = 'general',
  });
}

class TodoItemAdapter extends TypeAdapter<TodoItem> {
  @override
  final int typeId = 20;

  @override
  TodoItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return TodoItem(
      id: fields[0] as String,
      title: fields[1] as String,
      isCompleted: fields[2] as bool? ?? false,
      createdAt: fields[3] as DateTime,
      dueDate: fields[4] as DateTime?,
      priority: fields[5] as int? ?? 1,
      linkedEventId: fields[6] as String?,
      linkedDoubtId: fields[7] as String?,
      category: fields[8] as String? ?? 'general',
    );
  }

  @override
  void write(BinaryWriter writer, TodoItem obj) {
    writer.writeByte(9);
    writer.writeByte(0); writer.write(obj.id);
    writer.writeByte(1); writer.write(obj.title);
    writer.writeByte(2); writer.write(obj.isCompleted);
    writer.writeByte(3); writer.write(obj.createdAt);
    writer.writeByte(4); writer.write(obj.dueDate);
    writer.writeByte(5); writer.write(obj.priority);
    writer.writeByte(6); writer.write(obj.linkedEventId);
    writer.writeByte(7); writer.write(obj.linkedDoubtId);
    writer.writeByte(8); writer.write(obj.category);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 🍅 POMODORO SESSION
// ═══════════════════════════════════════════════════════════════════════════════

@HiveType(typeId: 21)
class PomodoroSession extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  int focusMinutes; // default 25

  @HiveField(2)
  int breakMinutes; // default 5

  @HiveField(3)
  int longBreakMinutes; // default 15

  @HiveField(4)
  int sessionsBeforeLongBreak; // default 4

  @HiveField(5)
  int completedSessions;

  @HiveField(6)
  int totalFocusMinutesToday;

  @HiveField(7)
  DateTime date;

  @HiveField(8)
  String? linkedTodoId; // Focus on a specific todo

  @HiveField(9)
  String? linkedBlockRuleId; // Auto-block apps during focus

  PomodoroSession({
    required this.id,
    this.focusMinutes = 25,
    this.breakMinutes = 5,
    this.longBreakMinutes = 15,
    this.sessionsBeforeLongBreak = 4,
    this.completedSessions = 0,
    this.totalFocusMinutesToday = 0,
    required this.date,
    this.linkedTodoId,
    this.linkedBlockRuleId,
  });
}

class PomodoroSessionAdapter extends TypeAdapter<PomodoroSession> {
  @override
  final int typeId = 21;

  @override
  PomodoroSession read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return PomodoroSession(
      id: fields[0] as String,
      focusMinutes: fields[1] as int? ?? 25,
      breakMinutes: fields[2] as int? ?? 5,
      longBreakMinutes: fields[3] as int? ?? 15,
      sessionsBeforeLongBreak: fields[4] as int? ?? 4,
      completedSessions: fields[5] as int? ?? 0,
      totalFocusMinutesToday: fields[6] as int? ?? 0,
      date: fields[7] as DateTime,
      linkedTodoId: fields[8] as String?,
      linkedBlockRuleId: fields[9] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, PomodoroSession obj) {
    writer.writeByte(10);
    writer.writeByte(0); writer.write(obj.id);
    writer.writeByte(1); writer.write(obj.focusMinutes);
    writer.writeByte(2); writer.write(obj.breakMinutes);
    writer.writeByte(3); writer.write(obj.longBreakMinutes);
    writer.writeByte(4); writer.write(obj.sessionsBeforeLongBreak);
    writer.writeByte(5); writer.write(obj.completedSessions);
    writer.writeByte(6); writer.write(obj.totalFocusMinutesToday);
    writer.writeByte(7); writer.write(obj.date);
    writer.writeByte(8); writer.write(obj.linkedTodoId);
    writer.writeByte(9); writer.write(obj.linkedBlockRuleId);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 📝 ACADEMIC DOUBT / NOTE
// ═══════════════════════════════════════════════════════════════════════════════

@HiveType(typeId: 22)
class AcademicDoubt extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String subject; // e.g. 'Physics', 'Math', 'History'

  @HiveField(2)
  String question;

  @HiveField(3)
  String? answer; // User can fill later when resolved

  @HiveField(4)
  bool isResolved;

  @HiveField(5)
  DateTime createdAt;

  @HiveField(6)
  DateTime? resolvedAt;

  @HiveField(7)
  int urgency; // 0=low, 1=medium, 2=high

  @HiveField(8)
  String? linkedTodoId; // Create a todo from this doubt

  @HiveField(9)
  List<String> tags; // e.g. ['exam', 'homework', 'revision']

  AcademicDoubt({
    required this.id,
    required this.subject,
    required this.question,
    this.answer,
    this.isResolved = false,
    required this.createdAt,
    this.resolvedAt,
    this.urgency = 1,
    this.linkedTodoId,
    List<String>? tags,
  }) : tags = tags ?? [];
}

class AcademicDoubtAdapter extends TypeAdapter<AcademicDoubt> {
  @override
  final int typeId = 22;

  @override
  AcademicDoubt read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return AcademicDoubt(
      id: fields[0] as String,
      subject: fields[1] as String,
      question: fields[2] as String,
      answer: fields[3] as String?,
      isResolved: fields[4] as bool? ?? false,
      createdAt: fields[5] as DateTime,
      resolvedAt: fields[6] as DateTime?,
      urgency: fields[7] as int? ?? 1,
      linkedTodoId: fields[8] as String?,
      tags: (fields[9] as List?)?.cast<String>() ?? [],
    );
  }

  @override
  void write(BinaryWriter writer, AcademicDoubt obj) {
    writer.writeByte(10);
    writer.writeByte(0); writer.write(obj.id);
    writer.writeByte(1); writer.write(obj.subject);
    writer.writeByte(2); writer.write(obj.question);
    writer.writeByte(3); writer.write(obj.answer);
    writer.writeByte(4); writer.write(obj.isResolved);
    writer.writeByte(5); writer.write(obj.createdAt);
    writer.writeByte(6); writer.write(obj.resolvedAt);
    writer.writeByte(7); writer.write(obj.urgency);
    writer.writeByte(8); writer.write(obj.linkedTodoId);
    writer.writeByte(9); writer.write(obj.tags);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 📅 PRODUCTIVITY EVENT (Calendar-integrated)
// ═══════════════════════════════════════════════════════════════════════════════

@HiveType(typeId: 23)
class ProductivityEvent extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String? description;

  @HiveField(3)
  DateTime startTime;

  @HiveField(4)
  DateTime? endTime;

  @HiveField(5)
  String color; // hex string for event color

  @HiveField(6)
  bool isAllDay;

  @HiveField(7)
  String? linkedTodoId; // Connect event → todo

  @HiveField(8)
  String? linkedBlockRuleId; // Auto-block apps during this event

  @HiveField(9)
  bool hasReminder;

  @HiveField(10)
  int reminderMinutesBefore; // 5, 10, 15, 30, 60

  @HiveField(11)
  String repeatType; // 'none', 'daily', 'weekly', 'monthly'

  ProductivityEvent({
    required this.id,
    required this.title,
    this.description,
    required this.startTime,
    this.endTime,
    this.color = 'C2A366',
    this.isAllDay = false,
    this.linkedTodoId,
    this.linkedBlockRuleId,
    this.hasReminder = false,
    this.reminderMinutesBefore = 15,
    this.repeatType = 'none',
  });
}

class ProductivityEventAdapter extends TypeAdapter<ProductivityEvent> {
  @override
  final int typeId = 23;

  @override
  ProductivityEvent read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return ProductivityEvent(
      id: fields[0] as String,
      title: fields[1] as String,
      description: fields[2] as String?,
      startTime: fields[3] as DateTime,
      endTime: fields[4] as DateTime?,
      color: fields[5] as String? ?? 'C2A366',
      isAllDay: fields[6] as bool? ?? false,
      linkedTodoId: fields[7] as String?,
      linkedBlockRuleId: fields[8] as String?,
      hasReminder: fields[9] as bool? ?? false,
      reminderMinutesBefore: fields[10] as int? ?? 15,
      repeatType: fields[11] as String? ?? 'none',
    );
  }

  @override
  void write(BinaryWriter writer, ProductivityEvent obj) {
    writer.writeByte(12);
    writer.writeByte(0); writer.write(obj.id);
    writer.writeByte(1); writer.write(obj.title);
    writer.writeByte(2); writer.write(obj.description);
    writer.writeByte(3); writer.write(obj.startTime);
    writer.writeByte(4); writer.write(obj.endTime);
    writer.writeByte(5); writer.write(obj.color);
    writer.writeByte(6); writer.write(obj.isAllDay);
    writer.writeByte(7); writer.write(obj.linkedTodoId);
    writer.writeByte(8); writer.write(obj.linkedBlockRuleId);
    writer.writeByte(9); writer.write(obj.hasReminder);
    writer.writeByte(10); writer.write(obj.reminderMinutesBefore);
    writer.writeByte(11); writer.write(obj.repeatType);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 🛡️ APP BLOCK RULE (Opal-style time/event-based app blocking)
// ═══════════════════════════════════════════════════════════════════════════════

@HiveType(typeId: 24)
class AppBlockRule extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name; // e.g. 'Study Mode', 'Sleep Mode'

  @HiveField(2)
  List<String> blockedPackages; // List of package names to block

  @HiveField(3)
  bool isEnabled;

  @HiveField(4)
  bool isTimeBased; // true = scheduled, false = manual toggle

  @HiveField(5)
  int? startHour; // 0-23 (for time-based)

  @HiveField(6)
  int? startMinute;

  @HiveField(7)
  int? endHour;

  @HiveField(8)
  int? endMinute;

  @HiveField(9)
  List<int> activeDays; // 1=Mon..7=Sun (for time-based)

  @HiveField(10)
  String? linkedEventId; // Block apps during this event

  @HiveField(11)
  String blockMessage; // Shown when blocked app is launched

  @HiveField(12)
  bool allowBreaks; // Allow 5-min breaks

  @HiveField(13)
  int breaksTaken;

  @HiveField(14)
  int maxBreaksPerSession;

  @HiveField(15)
  bool isHardBlock; // Premium: cannot be deleted, toggled, or edited

  @HiveField(16)
  DateTime? expiresAt; // For duration-based blocks — auto-disable after this time

  @HiveField(17)
  DateTime? snoozedUntil; // Paused until this time (usually next midnight) — auto-resumes after

  AppBlockRule({
    required this.id,
    required this.name,
    List<String>? blockedPackages,
    this.isEnabled = true,
    this.isTimeBased = false,
    this.startHour,
    this.startMinute,
    this.endHour,
    this.endMinute,
    List<int>? activeDays,
    this.linkedEventId,
    this.blockMessage = 'Stay focused! 🌙',
    this.allowBreaks = true,
    this.breaksTaken = 0,
    this.maxBreaksPerSession = 3,
    this.isHardBlock = false,
    this.expiresAt,
    this.snoozedUntil,
  })  : blockedPackages = blockedPackages ?? [],
        activeDays = activeDays ?? [1, 2, 3, 4, 5, 6, 7];

  /// True when the rule is temporarily paused (snoozed) and hasn't resumed yet.
  bool get isSnoozed =>
      snoozedUntil != null && DateTime.now().isBefore(snoozedUntil!);
}

class AppBlockRuleAdapter extends TypeAdapter<AppBlockRule> {
  @override
  final int typeId = 24;

  @override
  AppBlockRule read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return AppBlockRule(
      id: fields[0] as String,
      name: fields[1] as String,
      blockedPackages: (fields[2] as List?)?.cast<String>() ?? [],
      isEnabled: fields[3] as bool? ?? true,
      isTimeBased: fields[4] as bool? ?? false,
      startHour: fields[5] as int?,
      startMinute: fields[6] as int?,
      endHour: fields[7] as int?,
      endMinute: fields[8] as int?,
      activeDays: (fields[9] as List?)?.cast<int>() ?? [1, 2, 3, 4, 5, 6, 7],
      linkedEventId: fields[10] as String?,
      blockMessage: fields[11] as String? ?? 'Stay focused! 🌙',
      allowBreaks: fields[12] as bool? ?? true,
      breaksTaken: fields[13] as int? ?? 0,
      maxBreaksPerSession: fields[14] as int? ?? 3,
      isHardBlock: fields[15] as bool? ?? false,
      expiresAt: fields.containsKey(16) && fields[16] != null
          ? DateTime.fromMillisecondsSinceEpoch(fields[16] as int)
          : null,
      snoozedUntil: fields.containsKey(17) && fields[17] != null
          ? DateTime.fromMillisecondsSinceEpoch(fields[17] as int)
          : null,
    );
  }

  @override
  void write(BinaryWriter writer, AppBlockRule obj) {
    writer.writeByte(18);
    writer.writeByte(0); writer.write(obj.id);
    writer.writeByte(1); writer.write(obj.name);
    writer.writeByte(2); writer.write(obj.blockedPackages);
    writer.writeByte(3); writer.write(obj.isEnabled);
    writer.writeByte(4); writer.write(obj.isTimeBased);
    writer.writeByte(5); writer.write(obj.startHour);
    writer.writeByte(6); writer.write(obj.startMinute);
    writer.writeByte(7); writer.write(obj.endHour);
    writer.writeByte(8); writer.write(obj.endMinute);
    writer.writeByte(9); writer.write(obj.activeDays);
    writer.writeByte(10); writer.write(obj.linkedEventId);
    writer.writeByte(11); writer.write(obj.blockMessage);
    writer.writeByte(12); writer.write(obj.allowBreaks);
    writer.writeByte(13); writer.write(obj.breaksTaken);
    writer.writeByte(14); writer.write(obj.maxBreaksPerSession);
    writer.writeByte(15); writer.write(obj.isHardBlock);
    writer.writeByte(16); writer.write(obj.expiresAt?.millisecondsSinceEpoch);
    writer.writeByte(17); writer.write(obj.snoozedUntil?.millisecondsSinceEpoch);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 🍅 POMODORO SETTINGS (persisted user preferences)
// ═══════════════════════════════════════════════════════════════════════════════

@HiveType(typeId: 25)
class PomodoroSettings extends HiveObject {
  @HiveField(0)
  int focusMinutes;

  @HiveField(1)
  int shortBreakMinutes;

  @HiveField(2)
  int longBreakMinutes;

  @HiveField(3)
  int sessionsBeforeLongBreak;

  @HiveField(4)
  bool autoStartBreaks;

  @HiveField(5)
  bool autoStartFocus;

  @HiveField(6)
  bool soundEnabled;

  @HiveField(7)
  String? autoBlockRuleId; // Auto-enable this block rule during focus

  PomodoroSettings({
    this.focusMinutes = 25,
    this.shortBreakMinutes = 5,
    this.longBreakMinutes = 15,
    this.sessionsBeforeLongBreak = 4,
    this.autoStartBreaks = false,
    this.autoStartFocus = false,
    this.soundEnabled = true,
    this.autoBlockRuleId,
  });
}

class PomodoroSettingsAdapter extends TypeAdapter<PomodoroSettings> {
  @override
  final int typeId = 25;

  @override
  PomodoroSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return PomodoroSettings(
      focusMinutes: fields[0] as int? ?? 25,
      shortBreakMinutes: fields[1] as int? ?? 5,
      longBreakMinutes: fields[2] as int? ?? 15,
      sessionsBeforeLongBreak: fields[3] as int? ?? 4,
      autoStartBreaks: fields[4] as bool? ?? false,
      autoStartFocus: fields[5] as bool? ?? false,
      soundEnabled: fields[6] as bool? ?? true,
      autoBlockRuleId: fields[7] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, PomodoroSettings obj) {
    writer.writeByte(8);
    writer.writeByte(0); writer.write(obj.focusMinutes);
    writer.writeByte(1); writer.write(obj.shortBreakMinutes);
    writer.writeByte(2); writer.write(obj.longBreakMinutes);
    writer.writeByte(3); writer.write(obj.sessionsBeforeLongBreak);
    writer.writeByte(4); writer.write(obj.autoStartBreaks);
    writer.writeByte(5); writer.write(obj.autoStartFocus);
    writer.writeByte(6); writer.write(obj.soundEnabled);
    writer.writeByte(7); writer.write(obj.autoBlockRuleId);
  }
}
