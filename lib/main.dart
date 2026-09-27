import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:convert';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => KhataProvider(),
      child: const KhataProApp(),
    ),
  );
}

class KhataProvider extends ChangeNotifier {
  List<Map<String, dynamic>> transactions = [];
  double budget = 30000;
  KhataProvider() { loadData(); }

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('khata_pro_black');
    if (data != null) {
      transactions = List<Map<String, dynamic>>.from(jsonDecode(data));
      budget = prefs.getDouble('budget_black') ?? 30000;
      notifyListeners();
    }
  }

  Future<void> saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('khata_pro_black', jsonEncode(transactions));
    await prefs.setDouble('budget_black', budget);
  }

  void addTransaction(String title, double amount, String type, String category) {
    transactions.insert(0, {
      'title': title,
      'amount': amount,
      'type': type,
      'category': category,
      'date': DateTime.now().toIso8601String(),
    });
    saveData();
    notifyListeners();
  }

  double get totalIncome => transactions.where((t) => t['type'] == 'income').fold(0.0, (s, t) => s + t['amount']);
  double get totalExpense => transactions.where((t) => t['type'] == 'expense').fold(0.0, (s, t) => s + t['amount']);
  double get balance => totalIncome - totalExpense + budget;
}

class KhataProApp extends StatelessWidget {
  const KhataProApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Khata PRO Black',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        useMaterial3: true,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFBB86FC),
          secondary: Color(0xFF03DAC6),
          background: Colors.black,
          surface: Color(0xFF121212),
        ),
        textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
        appBarTheme: const AppBarTheme(backgroundColor: Colors.black, elevation: 0),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _index = 0;
  final pages = [const DashboardPage(), const TransactionPage(), const StatsPage()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: pages[_index],
      bottomNavigationBar: NavigationBarTheme(
        data: const NavigationBarThemeData(backgroundColor: Color(0xFF121212), indicatorColor: Color(0xFFBB86FC)),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.dashboard_rounded, color: Colors.white70), selectedIcon: Icon(Icons.dashboard_rounded, color: Colors.black), label: 'Dashboard'),
            NavigationDestination(icon: Icon(Icons.list_alt_rounded, color: Colors.white70), selectedIcon: Icon(Icons.list_alt_rounded, color: Colors.black), label: 'Khata'),
            NavigationDestination(icon: Icon(Icons.bar_chart_rounded, color: Colors.white70), selectedIcon: Icon(Icons.bar_chart_rounded, color: Colors.black), label: 'Stats'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFBB86FC),
        foregroundColor: Colors.black,
        onPressed: () => showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: const Color(0xFF1E1E1E), builder: (_) => const AddTransactionSheet()),
        label: const Text('ADD', style: TextStyle(fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.add),
      ),
    );
  }
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});
  @override
  Widget build(BuildContext context) {
    final khata = context.watch<KhataProvider>();
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // BLACK PRO CARD
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1F1F1F), Color(0xFF121212)]),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('KHATA PRO • BLACK', style: GoogleFonts.poppins(color: Colors.white38, fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.bold)),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: const Color(0xFFBB86FC), borderRadius: BorderRadius.circular(6)), child: const Text('PRO', style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold))),
                  ],
                ),
                const SizedBox(height: 12),
                Text('Total Balance', style: GoogleFonts.poppins(color: Colors.white54, fontSize: 14)),
                const SizedBox(height: 4),
                Text('₹ ${khata.balance.toStringAsFixed(0)}', style: GoogleFonts.poppins(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold)),
                const SizedBox(height: 18),
                Row(
                  children: [
                    _ProChip(title: 'INCOME', amount: khata.totalIncome, color: const Color(0xFF03DAC6)),
                    const SizedBox(width: 12),
                    _ProChip(title: 'EXPENSE', amount: khata.totalExpense, color: const Color(0xFFFF6B6B)),
                  ],
                )
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _ActionBtn(icon: Icons.picture_as_pdf, label: 'PDF', onTap: () async {
                final pdf = pw.Document();
                pdf.addPage(pw.Page(build: (c) => pw.Column(children: [pw.Text('Khata PRO BLACK Report', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)), pw.SizedBox(height: 20), pw.Text('Balance: ${khata.balance}'), pw.Text('Income: ${khata.totalIncome}'), pw.Text('Expense: ${khata.totalExpense}')]))); 
                await Printing.sharePdf(bytes: await pdf.save(), filename: 'khata-black.pdf');
              })),
              const SizedBox(width: 10),
              Expanded(child: _ActionBtn(icon: Icons.share, label: 'SHARE', onTap: () => Share.share('My KHATA PRO BLACK Balance: Rs. ${khata.balance}'))),
              const SizedBox(width: 10),
              Expanded(child: _ActionBtn(icon: Icons.delete_sweep, label: 'CLEAR', onTap: () { khata.transactions.clear(); khata.saveData(); khata.notifyListeners(); })),
            ],
          ),
          const SizedBox(height: 24),
          Text('RECENT', style: GoogleFonts.poppins(fontSize: 12, color: Colors.white38, letterSpacing: 2, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ...khata.transactions.take(6).map((t) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(color: const Color(0xFF121212), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white10)),
            child: ListTile(
              leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: t['type'] == 'income' ? const Color(0xFF03DAC6).withOpacity(0.2) : const Color(0xFFFF6B6B).withOpacity(0.2), shape: BoxShape.circle), child: Icon(t['type'] == 'income' ? Icons.arrow_upward : Icons.arrow_downward, color: t['type'] == 'income' ? const Color(0xFF03DAC6) : const Color(0xFFFF6B6B), size: 18)),
              title: Text(t['title'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
              subtitle: Text(t['category'], style: const TextStyle(color: Colors.white38, fontSize: 12)),
              trailing: Text('₹${t['amount']}', style: TextStyle(fontWeight: FontWeight.bold, color: t['type'] == 'income' ? const Color(0xFF03DAC6) : Colors.white)),
            ),
          )),
        ],
      ),
    );
  }
}

class _ProChip extends StatelessWidget {
  final String title; final double amount; final Color color;
  const _ProChip({required this.title, required this.amount, required this.color});
  @override
  Widget build(BuildContext context) {
    return Expanded(child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)), const SizedBox(height: 4), Text('₹${amount.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))]))); 
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon; final String label; final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(onTap: onTap, child: Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)), child: Column(children: [Icon(icon, color: Colors.white70, size: 18), const SizedBox(height: 4), Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold))]))); 
  }
}

class TransactionPage extends StatelessWidget {
  const TransactionPage({super.key});
  @override
  Widget build(BuildContext context) {
    final khata = context.watch<KhataProvider>();
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('Full Khata'), backgroundColor: Colors.black),
      body: ListView.builder(
        itemCount: khata.transactions.length,
        itemBuilder: (c, i) {
          final t = khata.transactions[i];
          return Dismissible(key: Key(t['date']), background: Container(color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete, color: Colors.white)), onDismissed: (_) { khata.transactions.removeAt(i); khata.saveData(); khata.notifyListeners(); }, child: ListTile(title: Text(t['title'], style: const TextStyle(color: Colors.white)), subtitle: Text("${t['category']} • ${t['date'].toString().substring(0,10)}", style: const TextStyle(color: Colors.white38)), trailing: Text('₹${t['amount']}', style: TextStyle(color: t['type'] == 'income' ? const Color(0xFF03DAC6) : Colors.white, fontWeight: FontWeight.bold))));
        },
      ),
    );
  }
}

class StatsPage extends StatelessWidget {
  const StatsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final khata = context.watch<KhataProvider>();
    if(khata.transactions.isEmpty) return const Scaffold(backgroundColor: Colors.black, body: Center(child: Text('No Data Yet', style: TextStyle(color: Colors.white38))));
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('Stats'), backgroundColor: Colors.black),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: 220, child: PieChart(PieChartData(sectionsSpace: 4, centerSpaceRadius: 50, sections: [
              PieChartSectionData(value: khata.totalIncome == 0 ? 1 : khata.totalIncome, color: const Color(0xFF03DAC6), title: 'Income', radius: 70, titleStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              PieChartSectionData(value: khata.totalExpense == 0 ? 1 : khata.totalExpense, color: const Color(0xFFFF6B6B), title: 'Expense', radius: 70, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ]))),
            const SizedBox(height: 20),
            Text('BLACK PRO ANALYTICS', style: GoogleFonts.poppins(color: Colors.white38, letterSpacing: 2, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class AddTransactionSheet extends StatefulWidget {
  const AddTransactionSheet({super.key});
  @override
  State<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<AddTransactionSheet> {
  final titleCtrl = TextEditingController();
  final amountCtrl = TextEditingController();
  String type = 'expense';
  String category = 'Ghar';
  final SpeechToText _speech = SpeechToText();
  bool _listening = false;

  void _listen() async {
    if (!_listening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _listening = true);
        _speech.listen(onResult: (result) { setState(() { titleCtrl.text = result.recognizedWords; }); });
      }
    } else {
      setState(() => _listening = false);
      _speech.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Row(children: [Expanded(child: Text('NEW ENTRY', style: GoogleFonts.poppins(fontSize: 14, color: Colors.white38, letterSpacing: 2, fontWeight: FontWeight.bold))), IconButton(onPressed: _listen, icon: Icon(_listening ? Icons.mic : Icons.mic_none, color: _listening ? Colors.red : Colors.white70))]),
          const SizedBox(height: 12),
          TextField(controller: titleCtrl, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: 'Kya kharcha? (bol ke bhi)', labelStyle: const TextStyle(color: Colors.white54), filled: true, fillColor: Colors.white10, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
          const SizedBox(height: 12),
          TextField(controller: amountCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: 'Amount ₹', labelStyle: const TextStyle(color: Colors.white54), filled: true, fillColor: Colors.white10, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: DropdownButtonFormField(value: type, dropdownColor: const Color(0xFF1E1E1E), style: const TextStyle(color: Colors.white), items: const [DropdownMenuItem(value: 'expense', child: Text('Expense')), DropdownMenuItem(value: 'income', child: Text('Income'))], onChanged: (v) => setState(() => type = v!), decoration: InputDecoration(filled: true, fillColor: Colors.white10, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), labelText: 'Type', labelStyle: const TextStyle(color: Colors.white54)))),
            const SizedBox(width: 12),
            Expanded(child: DropdownButtonFormField(value: category, dropdownColor: const Color(0xFF1E1E1E), style: const TextStyle(color: Colors.white), items: const [DropdownMenuItem(value: 'Ghar', child: Text('Ghar')), DropdownMenuItem(value: 'Kirana', child: Text('Kirana')), DropdownMenuItem(value: 'Bills', child: Text('Bills')), DropdownMenuItem(value: 'Personal', child: Text('Personal'))], onChanged: (v) => setState(() => category = v!), decoration: InputDecoration(filled: true, fillColor: Colors.white10, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), labelText: 'Category', labelStyle: const TextStyle(color: Colors.white54)))),
          ]),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, height: 52, child: FilledButton(style: FilledButton.styleFrom(backgroundColor: const Color(0xFFBB86FC), foregroundColor: Colors.black), onPressed: () {
            if (titleCtrl.text.isNotEmpty && amountCtrl.text.isNotEmpty) {
              context.read<KhataProvider>().addTransaction(titleCtrl.text, double.tryParse(amountCtrl.text) ?? 0, type, category);
              Navigator.pop(context);
            }
          }, child: const Text('SAVE TO BLACK PRO', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)))),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
