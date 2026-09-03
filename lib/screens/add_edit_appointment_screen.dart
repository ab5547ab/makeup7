import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/appointment.dart';
import '../services/appointments_controller.dart';

class AddEditAppointmentScreen extends StatefulWidget {
  final DateTime initialDate;
  final Appointment? existing;

  const AddEditAppointmentScreen({
    super.key,
    required this.initialDate,
    this.existing,
  });

  @override
  State<AddEditAppointmentScreen> createState() =>
      _AddEditAppointmentScreenState();
}

class _AddEditAppointmentScreenState extends State<AddEditAppointmentScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _notesCtrl;

  late DateTime _date;
  late TimeOfDay _time;
  late int _duration;
  late String _category;
  late AppointmentStatus _status;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameCtrl = TextEditingController(text: existing?.clientName ?? '');
    _phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    _priceCtrl =
        TextEditingController(text: existing?.price.toStringAsFixed(0) ?? '');
    _notesCtrl = TextEditingController(text: existing?.notes ?? '');
    _date = existing?.dateTime ?? widget.initialDate;
    _time = TimeOfDay.fromDateTime(existing?.dateTime ?? DateTime.now());
    _duration = existing?.durationMinutes ?? 60;
    _category = existing?.category ?? AppointmentCategory.all.first.name;
    _status = existing?.status ?? AppointmentStatus.confirmed;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _priceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'עריכת תור' : 'תור חדש'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'מחיקה',
              onPressed: _delete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'שם הלקוחה *',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'שדה חובה' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'טלפון',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(DateFormat('dd/MM/yyyy').format(_date)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickTime,
                    icon: const Icon(Icons.access_time),
                    label: Text(_time.format(context)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('משך זמן: $_duration דקות',
                style: Theme.of(context).textTheme.titleMedium),
            Slider(
              value: _duration.toDouble(),
              min: 15,
              max: 240,
              divisions: 15,
              label: '$_duration דק\'',
              onChanged: (v) => setState(() => _duration = v.round()),
            ),
            const SizedBox(height: 8),
            Text('קטגוריה', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AppointmentCategory.all.map((c) {
                final selected = c.name == _category;
                return ChoiceChip(
                  label: Text(c.name),
                  avatar: Icon(c.icon,
                      size: 18, color: selected ? Colors.white : c.color),
                  selected: selected,
                  selectedColor: c.color,
                  labelStyle: TextStyle(
                      color: selected ? Colors.white : Colors.black87),
                  onSelected: (_) => setState(() => _category = c.name),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Text('סטטוס', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AppointmentStatus.values.map((s) {
                final selected = s == _status;
                return ChoiceChip(
                  label: Text(s.label),
                  selected: selected,
                  selectedColor: s.color,
                  labelStyle: TextStyle(
                      color: selected ? Colors.white : Colors.black87),
                  onSelected: (_) => setState(() => _status = s),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _priceCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'מחיר (₪)',
                prefixIcon: Icon(Icons.payments_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'הערות',
                prefixIcon: Icon(Icons.notes_outlined),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: Text(_isEditing ? 'שמירת שינויים' : 'הוספת תור'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final combined = DateTime(
        _date.year, _date.month, _date.day, _time.hour, _time.minute);
    final price = double.tryParse(_priceCtrl.text.trim()) ?? 0;

    final controller = context.read<AppointmentsController>();

    if (_isEditing) {
      final updated = widget.existing!.copyWith(
        clientName: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        dateTime: combined,
        durationMinutes: _duration,
        category: _category,
        price: price,
        notes: _notesCtrl.text.trim(),
        status: _status,
      );
      controller.update(updated);
    } else {
      final newAppointment = Appointment(
        id: const Uuid().v4(),
        clientName: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        dateTime: combined,
        durationMinutes: _duration,
        category: _category,
        price: price,
        notes: _notesCtrl.text.trim(),
        status: _status,
        updatedAt: DateTime.now(),
      );
      controller.add(newAppointment);
    }

    Navigator.pop(context);
  }

  void _delete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('מחיקת תור'),
        content: const Text('האם למחוק את התור הזה לצמיתות?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('ביטול')),
          TextButton(
            onPressed: () {
              context.read<AppointmentsController>().delete(widget.existing!.id);
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('מחק', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
