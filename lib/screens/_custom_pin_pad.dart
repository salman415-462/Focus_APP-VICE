import 'package:flutter/material.dart';

class CustomPinPad extends StatefulWidget {
  final String title;
  final String subtitle;
  final ValueChanged<String> onPinEntered;
  final VoidCallback onCancel;
  final int pinLength;

  const CustomPinPad({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onPinEntered,
    required this.onCancel,
    this.pinLength = 4,
  });

  @override
  State<CustomPinPad> createState() => _CustomPinPadState();
}

class _CustomPinPadState extends State<CustomPinPad>
    with SingleTickerProviderStateMixin {
  final List<String> _enteredPin = [];
  late AnimationController _shakeController;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _onNumberPressed(String number) {
    if (_enteredPin.length < widget.pinLength) {
      setState(() {
        _enteredPin.add(number);
      });

      if (_enteredPin.length >= widget.pinLength) {
        _checkPin();
      }
    }
  }

  void _onBackspacePressed() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin.removeLast();
      });
    }
  }

  void _checkPin() {
    final pin = _enteredPin.join('');
    widget.onPinEntered(pin);
  }

  void triggerError() async {
    setState(() {
      _isError = true;
      _enteredPin.clear();
    });

    await _shakeController.forward();
    _shakeController.reset();
    setState(() {
      _isError = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shakeController,
      builder: (context, child) {
        final shakeOffset = Tween<Offset>(
          begin: Offset.zero,
          end: const Offset(-0.02, 0),
        ).animate(
          CurvedAnimation(
            parent: _shakeController,
            curve: const Interval(0.0, 0.1, curve: Curves.easeInOut),
          ),
        );

        final shakeOffset2 = Tween<Offset>(
          begin: Offset.zero,
          end: const Offset(0.02, 0),
        ).animate(
          CurvedAnimation(
            parent: _shakeController,
            curve: const Interval(0.1, 0.2, curve: Curves.easeInOut),
          ),
        );

        final shakeOffset3 = Tween<Offset>(
          begin: Offset.zero,
          end: const Offset(-0.02, 0),
        ).animate(
          CurvedAnimation(
            parent: _shakeController,
            curve: const Interval(0.2, 0.3, curve: Curves.easeInOut),
          ),
        );

        final shakeOffset4 = Tween<Offset>(
          begin: Offset.zero,
          end: const Offset(0.02, 0),
        ).animate(
          CurvedAnimation(
            parent: _shakeController,
            curve: const Interval(0.3, 0.4, curve: Curves.easeInOut),
          ),
        );

        final animationValue = _shakeController.value;

        Offset getOffset() {
          if (animationValue < 0.1) return shakeOffset.value;
          if (animationValue < 0.2) return shakeOffset2.value;
          if (animationValue < 0.3) return shakeOffset3.value;
          if (animationValue < 0.4) return shakeOffset4.value;
          return Offset.zero;
        }

        return Transform.translate(
          offset: getOffset() * 50,
          child: child,
        );
      },
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFDF2),
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.14),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            const SizedBox(height: 32),
            _buildPinDots(),
            const SizedBox(height: 40),
            _buildKeypad(),
            const SizedBox(height: 24),
            _buildCancelButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xFFE6EFE3).withOpacity(0.8),
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFF4E6E3A).withOpacity(0.3),
              width: 1,
            ),
          ),
          child: const Icon(
            Icons.shield_outlined,
            color: Color(0xFF4E6E3A),
            size: 28,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          widget.title,
          style: const TextStyle(
            color: Color(0xFF2C2C25),
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.subtitle,
          style: const TextStyle(
            color: Color(0xFF7A7A70),
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildPinDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        widget.pinLength,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: index < _enteredPin.length
                ? _isError
                    ? const Color(0xFFB57A7A)
                    : const Color(0xFF4E6E3A)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(50),
            border: Border.all(
              color: index < _enteredPin.length
                  ? _isError
                      ? const Color(0xFFB57A7A)
                      : const Color(0xFF4E6E3A)
                  : const Color(0xFFD4D4C8),
              width: 2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeypad() {
    final buttons = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['⌫', '0', ''],
    ];

    return Column(
      children: buttons.map((row) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: row.map((btn) {
            if (btn == '⌫') {
              return _buildKeypadButton(
                onTap: _onBackspacePressed,
                child: const Icon(
                  Icons.backspace_outlined,
                  color: Color(0xFF7A7A70),
                  size: 24,
                ),
              );
            } else if (btn.isEmpty) {
              return const SizedBox(width: 72, height: 72);
            } else {
              return _buildKeypadButton(
                onTap: () => _onNumberPressed(btn),
                child: Text(
                  btn,
                  style: const TextStyle(
                    color: Color(0xFF2C2C25),
                    fontSize: 28,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              );
            }
          }).toList(),
        );
      }).toList(),
    );
  }

  Widget _buildKeypadButton({
    required VoidCallback onTap,
    required Widget child,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        height: 72,
        margin: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: const Color(0xFFF0EFE8),
            width: 1,
          ),
        ),
        child: Center(child: child),
      ),
    );
  }

  Widget _buildCancelButton() {
    return GestureDetector(
      onTap: () {
        widget.onCancel();
        Navigator.of(context).pop();
      },
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Text(
          'Cancel',
          style: TextStyle(
            color: Color(0xFF9E9E92),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class PinPadDialog extends StatefulWidget {
  final String title;
  final String subtitle;
  final ValueChanged<String> onPinEntered;
  final VoidCallback onCancel;
  final int pinLength;
  final bool isSetMode;
  final String? firstPinToConfirm;
  final bool Function(String pin)? onVerifyPin;

  const PinPadDialog({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onPinEntered,
    required this.onCancel,
    this.pinLength = 4,
    this.isSetMode = false,
    this.firstPinToConfirm,
    this.onVerifyPin,
  });

  @override
  State<PinPadDialog> createState() => _PinPadDialogState();
}

class _PinPadDialogState extends State<PinPadDialog> {
  late GlobalKey<_CustomPinPadState> _pinPadKey;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _pinPadKey = GlobalKey<_CustomPinPadState>();
  }

  void _handlePinEntered(String pin) {
    if (_isProcessing) return;
    
    if (widget.isSetMode) {
      if (widget.firstPinToConfirm != null) {
        if (pin == widget.firstPinToConfirm) {
          Navigator.of(context).pop();
          widget.onPinEntered(pin);
        } else {
          _showErrorAndClose('PINs do not match. Please try again.');
        }
      } else {
        _showConfirmationDialog(pin);
      }
    } else {
      if (widget.onVerifyPin != null) {
        _isProcessing = true;
        final isValid = widget.onVerifyPin!(pin);
        _isProcessing = false;
        
        if (isValid) {
          Navigator.of(context).pop();
          widget.onPinEntered(pin);
        } else {
          _pinPadKey.currentState?.triggerError();
        }
      } else {
        Navigator.of(context).pop();
        widget.onPinEntered(pin);
      }
    }
  }

  void _showConfirmationDialog(String firstPin) {
    Navigator.of(context).pop();
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          ),
          child: FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            ),
            child: child,
          ),
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) {
        return PinPadDialog(
          title: 'Confirm PIN',
          subtitle: 'Enter your PIN again to confirm',
          pinLength: widget.pinLength,
          isSetMode: true,
          firstPinToConfirm: firstPin,
          onPinEntered: widget.onPinEntered,
          onCancel: widget.onCancel,
        );
      },
    );
  }

  void _showErrorAndClose(String message) {
    Navigator.of(context).pop();
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFFFDF2),
        title: const Text(
          'Error',
          style: TextStyle(color: Color(0xFF2C2C25)),
        ),
        content: Text(
          message,
          style: const TextStyle(color: Color(0xFF7A7A70)),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4E6E3A),
              foregroundColor: const Color(0xFFF4F3EF),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void triggerError() {
    _pinPadKey.currentState?.triggerError();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: CustomPinPad(
        key: _pinPadKey,
        title: widget.title,
        subtitle: widget.subtitle,
        onPinEntered: _handlePinEntered,
        onCancel: () {
          widget.onCancel();
          Navigator.of(context).pop();
        },
        pinLength: widget.pinLength,
      ),
    );
  }
}

void showPinPadDialog({
  required BuildContext context,
  required String title,
  required String subtitle,
  required ValueChanged<String> onPinEntered,
  required VoidCallback onCancel,
  int pinLength = 4,
  bool isSetMode = false,
  String? firstPinToConfirm,
  bool Function(String pin)? onVerifyPin,
}) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 300),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return ScaleTransition(
        scale: CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        ),
        child: FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
          ),
          child: child,
        ),
      );
    },
    pageBuilder: (context, animation, secondaryAnimation) {
      return PinPadDialog(
        title: title,
        subtitle: subtitle,
        onPinEntered: onPinEntered,
        onCancel: onCancel,
        pinLength: pinLength,
        isSetMode: isSetMode,
        firstPinToConfirm: firstPinToConfirm,
        onVerifyPin: onVerifyPin,
      );
    },
  );
}
