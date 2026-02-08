import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class GlobalSupportButton extends StatelessWidget {
  final bool isDark;
  
  const GlobalSupportButton({
    super.key, 
    required this.isDark,
  });

  Future<void> _launchWhatsApp() async {
    final Uri url = Uri.parse('https://wa.me/917737886504');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      visualDensity: VisualDensity.compact, // Reduces layout size
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(), // Removes min size constraints
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap, // Removes implicit margin
      ),
      onPressed: _launchWhatsApp,
      tooltip: 'Support',
      icon: SizedBox(
        width: 24,
        height: 24,
        child: CustomPaint(
          painter: SupportIconPainter(
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }
}

class SupportIconPainter extends CustomPainter {
  final Color color;
  
  SupportIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8 // Slightly refined for cleaner lines
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;
    
    // 1. Ear Cups (Hollow Capsules) - Balanced width and height
    final earW = w * 0.14;
    final earH = h * 0.32;
    final earTop = h * 0.32;
    
    // Left Ear
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.11, earTop, earW, earH),
        const Radius.circular(6),
      ),
      paint
    );
    
    // Right Ear
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.75, earTop, earW, earH),
        const Radius.circular(6),
      ),
      paint
    );

    // 2. Headset Band - smoother arc
    final bandPath = Path();
    bandPath.moveTo(w * 0.18, earTop + 2); 
    bandPath.cubicTo(
      w * 0.18, h * 0.04, 
      w * 0.82, h * 0.04, 
      w * 0.82, earTop + 2 
    );
    canvas.drawPath(bandPath, paint);

    // 3. Face & Hair - Refined
    
    // Hair Swoosh - Fluid curve
    final hairPath = Path();
    hairPath.moveTo(w * 0.28, h * 0.44); // Start inside left
    // Upward sweep
    hairPath.cubicTo(
      w * 0.40, h * 0.28, // Control 1
      w * 0.60, h * 0.28, // Control 2
      w * 0.72, h * 0.30  // End right forehead
    );
    // Return sweep (bangs)
    hairPath.quadraticBezierTo(
        w * 0.68, h * 0.40,
        w * 0.66, h * 0.46 
    );
    canvas.drawPath(hairPath, paint);

    // Face / Chin - Natural U-shape
    final facePath = Path();
    // Left side below hair
    facePath.moveTo(w * 0.28, h * 0.44);
    // Chin curve
    facePath.moveTo(w * 0.26, h * 0.52);
    facePath.cubicTo(
      w * 0.26, h * 0.88, // Deep curve left
      w * 0.74, h * 0.88, // Deep curve right
      w * 0.74, h * 0.52  // End right
    );
    canvas.drawPath(facePath, paint);

    // 4. Microphone (Left side) - Clean arc
    final micStart = Offset(w * 0.25, h * 0.62); 
    final micEnd = Offset(w * 0.46, h * 0.76);   
    
    final micPath = Path();
    micPath.moveTo(micStart.dx, micStart.dy); 
    micPath.quadraticBezierTo(
      w * 0.28, h * 0.78, // Control point
      micEnd.dx, micEnd.dy 
    );
    canvas.drawPath(micPath, paint);

    // Mic Tip (Hollow Capsule) - Better proportion
    final micTipRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(w * 0.54, h * 0.76), width: w * 0.15, height: h * 0.08),
      const Radius.circular(10)
    );
    canvas.drawRRect(micTipRect, paint);


    // 5. Shoulders / Torso - Smoother transition
    final shoulderPath = Path();
    // Left base
    shoulderPath.moveTo(w * 0.12, h); 
    shoulderPath.lineTo(w * 0.12, h * 0.88);
    // Curve over neck
    shoulderPath.cubicTo(
      w * 0.12, h * 0.75, // Control left
      w * 0.35, h * 0.70, // Control neck left
      w * 0.50, h * 0.70  // Center neck (implied) - actually draw full arc
    );
    // Since it's a single stroke, let's span the whole shoulder width
    shoulderPath.reset();
    shoulderPath.moveTo(w * 0.12, h);
    shoulderPath.lineTo(w * 0.12, h * 0.88);
    shoulderPath.cubicTo(
        w * 0.12, h * 0.68,
        w * 0.88, h * 0.68,
        w * 0.88, h * 0.88
    );
    shoulderPath.lineTo(w * 0.88, h);
    
    canvas.drawPath(shoulderPath, paint);
  }

  @override
  bool shouldRepaint(covariant SupportIconPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
