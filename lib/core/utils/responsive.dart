// flutter_screenutil handles all responsive sizing.
// Import and use directly — no wrapper class needed.
//
// Usage:
//   16.w     → width relative to design (390px base)
//   16.h     → height relative to design (844px base)
//   16.r     → radius/icon size (scales on min dimension)
//   16.sp    → font size (respects accessibility text scale)
//   0.5.sw   → 50% of screen width
//   0.5.sh   → 50% of screen height
//
// Initialized via ScreenUtilInit in main.dart (designSize: 390×844).

export 'package:flutter_screenutil/flutter_screenutil.dart'
    show
        ScreenUtil,
        ScreenUtilInit,
        SizeExtension,
        EdgeInsetsExtension,
        BorderRadiusExtension,
        BoxConstraintsExtension;
