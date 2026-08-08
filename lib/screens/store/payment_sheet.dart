import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';


// NEED TO REPLACE WITH REAL IN APP PURCHASES 

class PaymentSheet extends StatefulWidget {
  final String productName;
  final String price;
  const PaymentSheet({required this.productName, required this.price});
  @override
  State<PaymentSheet> createState() => PaymentSheetState();
}

class PaymentSheetState extends State<PaymentSheet> {
  final _cardCtrl = TextEditingController();
  final _expiryCtrl = TextEditingController();
  final _cvcCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _busy = false;
  bool _success = false;
  String? _error;

  String _formatCard(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    final buf = StringBuffer();
    for (int i = 0; i < digits.length && i < 16; i++) {
      if (i > 0 && i % 4 == 0) buf.write(' ');
      buf.write(digits[i]);
    }
    return buf.toString();
  }

  String _formatExpiry(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length <= 2) return digits;
    return '${digits.substring(0, 2)}/${digits.substring(2, digits.length.clamp(0, 4))}';
  }

  bool get _valid =>
      _cardCtrl.text.replaceAll(' ', '').length == 16 &&
      _expiryCtrl.text.length == 5 &&
      _cvcCtrl.text.length >= 3 &&
      _nameCtrl.text.trim().isNotEmpty;

  Future<void> _pay() async {
    if (!_valid) { setState(() => _error = 'Please fill in all fields correctly.'); return; }
    setState(() { _busy = true; _error = null; });
    await Future.delayed(const Duration(milliseconds: 1800));
    setState(() { _busy = false; _success = true; });
    await Future.delayed(const Duration(milliseconds: 1200));
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _cardCtrl.dispose(); _expiryCtrl.dispose();
    _cvcCtrl.dispose(); _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        child: _success
            ? _SuccessState(productName: widget.productName)
            : Column(
                key: const ValueKey('form'),
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0E0E0),
                        borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(widget.productName, style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w800)),
                      Text('One-time purchase', style: GoogleFonts.dmSans(fontSize: 13, color: Colors.black45)),
                    ])),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C2C2C), borderRadius: BorderRadius.circular(12)),
                      child: Text(widget.price, style: GoogleFonts.dmSans(
                        fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
                    ),
                  ]),
                  const SizedBox(height: 24),
                  _PayField(label: 'CARDHOLDER NAME', controller: _nameCtrl,
                    hint: 'Jay Dev', keyboard: TextInputType.name),
                  const SizedBox(height: 12),
                  _PayField(
                    label: 'CARD NUMBER', controller: _cardCtrl,
                    hint: '1234 5678 9012 3456',
                    keyboard: TextInputType.number, maxLen: 19,
                    onChanged: (v) {
                      final formatted = _formatCard(v);
                      if (formatted != v) {
                        _cardCtrl.value = TextEditingValue(
                          text: formatted,
                          selection: TextSelection.collapsed(offset: formatted.length));
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _PayField(
                      label: 'EXPIRY', controller: _expiryCtrl,
                      hint: 'MM/YY', keyboard: TextInputType.number, maxLen: 5,
                      onChanged: (v) {
                        final formatted = _formatExpiry(v);
                        if (formatted != v) {
                          _expiryCtrl.value = TextEditingValue(
                            text: formatted,
                            selection: TextSelection.collapsed(offset: formatted.length));
                        }
                      },
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _PayField(
                      label: 'CVC', controller: _cvcCtrl,
                      hint: '•••', keyboard: TextInputType.number, maxLen: 4,
                      obscure: true,
                    )),
                  ]),
                  if (_error != null) Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(_error!, style: GoogleFonts.dmSans(fontSize: 13, color: Colors.red, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: _busy ? null : _pay,
                    child: Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C2C2C),
                        borderRadius: BorderRadius.circular(16)),
                      child: Center(
                        child: _busy
                            ? const SizedBox(width: 22, height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                            : Row(mainAxisSize: MainAxisSize.min, children: [
                                const Icon(Icons.lock_rounded, color: Colors.white54, size: 16),
                                const SizedBox(width: 8),
                                Text('Pay ${widget.price}', style: GoogleFonts.dmSans(
                                  fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                              ]),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.security_rounded, size: 13, color: Colors.black26),
                    const SizedBox(width: 4),
                    Text('Secured with 256-bit encryption',
                      style: GoogleFonts.dmSans(fontSize: 11, color: Colors.black26)),
                  ])),
                ],
              ),
      ),
    );
  }
}

class _PayField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final TextInputType keyboard;
  final int? maxLen;
  final bool obscure;
  final ValueChanged<String>? onChanged;

  const _PayField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.keyboard,
    this.maxLen,
    this.obscure = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w700,
        color: Colors.black38, letterSpacing: 1.1)),
      const SizedBox(height: 6),
      TextField(
        controller: controller,
        keyboardType: keyboard,
        obscureText: obscure,
        maxLength: maxLen,
        onChanged: onChanged,
        style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          counterText: '',
          hintText: hint,
          hintStyle: GoogleFonts.dmSans(color: Colors.black26),
          filled: true,
          fillColor: const Color(0xFFF5F5F5),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF2C2C2C), width: 1.5)),
        ),
      ),
    ]);
  }
}

class _SuccessState extends StatelessWidget {
  final String productName;
  const _SuccessState({required this.productName});
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 20),
        const Icon(Icons.check_circle_rounded, color: Color(0xFF4CAF50), size: 72),
        const SizedBox(height: 16),
        Text('Payment Successful!', style: GoogleFonts.dmSans(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text('$productName has been unlocked. Enjoy!', textAlign: TextAlign.center,
          style: GoogleFonts.dmSans(fontSize: 15, color: Colors.black54)),
        const SizedBox(height: 24),
      ],
    );
  }
}

