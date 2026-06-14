# CLAUDE.md — أسلوب العمل والمعمارية

## نظرة عامة

تطبيق **داليا** للموبايل (Android/iOS أولاً)، واجهة عربية كاملة (RTL)، قاعدة بيانات محلية ObjectBox.

### المميزات الرئيسية

| الميزة | التفاصيل |
|--------|----------|
| قراءة القرآن | تصفح السور والآيات، حجم خط قابل للتعديل، آخر موضع قراءة |
| أوقات الصلاة | حساب دقيق بـ `adhan`، عرض الصلاة القادمة مع العداد التنازلي |
| اتجاه القبلة | بوصلة حية بـ `flutter_compass`، المسافة إلى مكة |
| تنبيهات الصلاة | تُطلَق حتى عند إغلاق التطبيق تماماً (AlarmManager + WorkManager) |
| أصوات التنبيه | اختيار من أذان مكة / المدينة / مصري / تنبيه هادئ + معاينة قبل الاختيار |
| تذكير مسبق | تنبيه قبل الصلاة بـ ٥ / ١٠ / ١٥ / ٣٠ دقيقة (أو بدون تذكير) |
| وضع ليلي | Dark/Light mode محفوظ في SharedPreferences |
| حجم الخط | قابل للتكبير/التصغير (٠.٨× إلى ١.٦×) |

---

## هيكل خدمة التنبيهات (Background)

```
تنبيه حتى مع إغلاق التطبيق:
  AlarmManager (exactAllowWhileIdle)  ← flutter_local_notifications
       +
  WorkManager (يومي كل ٢٤ ساعة)      ← workmanager
       ↓
  يُعيد جدولة الصلوات الخمس كل يوم

UX — طلب الصلاحيات بالترتيب:
  1. POST_NOTIFICATIONS     (Android 13+)
  2. SCHEDULE_EXACT_ALARM   (Android 12+) — مع شرح واضح للمستخدم
  3. REQUEST_IGNORE_BATTERY_OPTIMIZATIONS — مرة واحدة فقط، مع dialog يشرح السبب
```

---

## اختيار نغمة التنبيه — UX Rules

1. **معاينة قبل الاختيار** — زر ▶ بجانب كل نغمة يشغّلها لثوانٍ (بدون حفظ)
2. **checkmark** على النغمة المختارة حالياً
3. **channel منفصل لكل نغمة** — Android يربط الصوت بالـ channel وقت الإنشاء، لا وقت الإرسال
4. **"نغمة النظام"** كخيار افتراضي دائماً (لا يحتاج ملف)
5. **لا تعيد إنشاء الـ channel** إذا لم يتغير الصوت — يسبب bugs في Android
6. **أصوات قصيرة** (١٠-٢٠ ثانية) لتقليل حجم التطبيق

```
assets/sounds/          ← للمعاينة داخل التطبيق (audioplayers)
android/app/src/main/res/raw/  ← للتنبيه الفعلي (flutter_local_notifications)
```

---

## المعمارية: Clean Architecture + Feature-first

```
lib/
├── core/
│   ├── di/               ← injection_container.dart (GetIt)
│   ├── errors/           ← failures.dart
│   ├── state/            ← cubits عامة (DateRangeCubit, FontScaleCubit, DataChangedNotifier)
│   ├── theme/            ← app_colors.dart, app_theme.dart, theme_cubit.dart
│   ├── utils/
│   └── constants/
├── features/
│   └── <feature_name>/
│       ├── data/
│       │   ├── models/         ← <name>_ob.dart  (ObjectBox entity)
│       │   ├── datasources/    ← <name>_local_datasource.dart
│       │   └── repositories/   ← <name>_repository_impl.dart
│       ├── domain/
│       │   ├── entities/       ← <name>_entity.dart (Equatable, copyWith)
│       │   ├── repositories/   ← <name>_repository.dart (abstract)
│       │   └── usecases/       ← <name>_usecases.dart (كلاس لكل عملية)
│       └── presentation/
│           ├── cubit/          ← <name>_cubit.dart (states + cubit في نفس الملف)
│           └── pages/          ← <name>_page.dart
├── shared/
│   └── widgets/          ← widgets مشتركة بين الفيتشرز
└── objectbox/            ← objectbox_store.dart + objectbox.g.dart
```

---

## قواعد التسمية

| الطبقة | الصيغة | مثال |
|--------|--------|------|
| ObjectBox model | `<Name>Ob` | `TransactionOb` |
| Domain entity | `<Name>Entity` | `TransactionEntity` |
| Repository (abstract) | `<Name>Repository` | `TransactionsRepository` |
| Repository (impl) | `<Name>RepositoryImpl` | `TransactionsRepositoryImpl` |
| Datasource | `<Name>LocalDatasource` | `TransactionsLocalDatasource` |
| Use case | فعل + اسم (كلاس منفصل) | `GetTransactions`, `AddTransaction` |
| Cubit | `<Name>Cubit` | `TransactionsCubit` |
| States | في نفس ملف الـ cubit | `TransactionsLoading`, `TransactionsLoaded`, `TransactionsError` |

---

## قواعد الكود

### Entities
- ترث من `Equatable`
- كل الحقول `final`
- `copyWith` إلزامي
- قيم افتراضية للحقول الاختيارية في الـ constructor

```dart
class TransactionEntity extends Equatable {
  final int id;
  // ...
  const TransactionEntity({required this.id, this.note = ''});
  @override
  List<Object?> get props => [id, ...];
  TransactionEntity copyWith({int? id, ...}) => TransactionEntity(id: id ?? this.id, ...);
}
```

### ObjectBox Models
- annotation `@Entity()` + `@Id()` + `@Property(type: PropertyType.date)` للتواريخ
- `id = 0` كقيمة افتراضية (ObjectBox يعين الـ id)
- لا ترث من Equatable

### Use Cases
- كلاس بسيط، فيه `repository` فقط
- دالة `call(...)` ترجع `Future<Either<Failure, T>>`
- كل use case في ملف واحد مع إخوانه

```dart
class AddTransaction {
  final TransactionsRepository repository;
  AddTransaction(this.repository);
  Future<Either<Failure, TransactionEntity>> call(TransactionEntity tx) =>
      repository.addTransaction(tx);
}
```

### Repository Implementation
- يحول بين `Entity` و `Ob` بدوال خاصة `_map()` و `_toOb()`
- كل method ملفوفة بـ try/catch ترجع `Left(DatabaseFailure(...))`
- الحذف soft delete: يضع `isDeleted = true`

### Cubits
- States في نفس الملف فوق الـ Cubit، مفصولة بتعليق `// ─── States ───`
- يحفظ آخر filter parameters (خاصة `_private`) لإعادة استخدامها في `reload()`
- بعد كل write → `reload()` ثم `notifier.notify()`

```dart
Future<void> add(T item) async =>
    (await addUseCase(item)).fold(
      (f) => emit(Error(f.message)),
      (_) => reload().then((_) => notifier.notify()),
    );
```

---

## Dependency Injection (GetIt)

- الـ instance العام: `final sl = GetIt.instance;`
- Datasources/Repositories/UseCases → `registerLazySingleton`
- Cubits → `registerFactory` (instance جديد في كل مرة)
- الـ ObjectBox store يُسجَّل في `main.dart` قبل `initDependencies()`

---

## إدارة الحالة العامة

| الـ Cubit | الغرض |
|-----------|-------|
| `DateRangeCubit` | نطاق التاريخ المحدد في كل الشاشات |
| `FontScaleCubit` | حجم الخط |
| `ThemeCubit` | الوضع الليلي/النهاري |
| `DataChangedNotifier` | `Stream<void>` يُطلَق بعد كل write لإعادة تحميل Dashboard/Reports |

---

## الألوان والثيم

- كل الألوان في `AppColors` (ثوابت static)
- للوصول الـ adaptive استخدم: `context.colors.surface`, `context.colors.textPrimary`, إلخ
- لا تكتب ألوان هاردكود في الـ widgets — استخدم `AppColors` أو `context.colors`

```dart
// صح
color: context.colors.card
// غلط
color: Color(0xFFFFFFFF)
```

---

## AppShell

- تتحكم في التنقل بـ `IndexedStack` (لا يتم destroy الصفحات)
- Aggregate cubits (Dashboard, Reports, LinkedOutflows) محفوظة في الـ State وتُعاد تحميلها عبر `DataChangedNotifier`
- باقي الصفحات تحصل على cubit جديد من `sl<XCubit>()` في كل مرة

---

## Responsive Design — flutter_screenutil

### الإعداد

`ScreenUtilInit` موجود في `main.dart` يُهيّئ النظام بـ design size = **390×844** (iPhone 14).

```dart
ScreenUtilInit(
  designSize: const Size(390, 844),
  minTextAdapt: true,
  splitScreenMode: true,
  builder: (context, child) => MaterialApp(...),
)
```

### قواعد الاستخدام (لا تستخدم أرقاماً ثابتة أبداً)

```dart
// غلط — رقم ثابت
Padding(padding: EdgeInsets.all(16))
Container(width: 300, height: 80)
Text('نص', style: TextStyle(fontSize: 18))

// صح — flutter_screenutil
Padding(padding: EdgeInsets.all(16.w))
Container(width: 300.w, height: 80.h)
Text('نص', style: TextStyle(fontSize: 18.sp))
```

### مرجع سريع للـ extensions

| Extension | الاستخدام | مثال |
|-----------|-----------|------|
| `.w` | عرض نسبي للـ design width | `16.w` |
| `.h` | ارتفاع نسبي للـ design height | `48.h` |
| `.r` | radius/icon — min(w, h) | `12.r` |
| `.sp` | حجم خط يراعي accessibility | `16.sp` |
| `.sw` | نسبة من عرض الشاشة الفعلي | `0.9.sw` |
| `.sh` | نسبة من ارتفاع الشاشة الفعلي | `0.5.sh` |

### LayoutBuilder للتخطيطات المعقدة

```dart
LayoutBuilder(
  builder: (context, constraints) {
    final isWide = constraints.maxWidth > 600;
    return isWide
        ? Row(children: [surahList, readingArea])
        : surahList;
  },
)
```

### SafeArea و MediaQuery Padding

- **دائماً** غلّف الشاشات بـ `SafeArea` لتجنب notch/camera cutout/bottom bar
- استخدم `MediaQuery.paddingOf(context).bottom` للـ bottom nav بدل ارتفاع ثابت
- استخدم `MediaQuery.viewInsetsOf(context).bottom` لتجنب تغطية الكيبورد

---

## أداء الموبايل والـ State Management الجزئي

### القاعدة الأساسية: لا تعيد بناء ما لم يتغير

**استخدم `BlocSelector` بدل `BlocBuilder` كلما أمكن** — يستمع فقط لجزء محدد من الـ state:

```dart
// غلط — يعيد البناء عند أي تغيير في الـ state
BlocBuilder<TransactionsCubit, TransactionsState>(
  builder: (context, state) => Text(state.total.toString()),
)

// صح — يعيد البناء فقط إذا تغيّر total
BlocSelector<TransactionsCubit, TransactionsState, double>(
  selector: (state) => state is TransactionsLoaded ? state.total : 0.0,
  builder: (context, total) => Text(total.toString()),
)
```

**استخدم `buildWhen`** لتحديد متى يُعاد البناء بناءً على مقارنة الـ state القديم والجديد:

```dart
BlocBuilder<TransactionsCubit, TransactionsState>(
  buildWhen: (previous, current) =>
      previous is! TransactionsLoaded ||
      current is! TransactionsLoaded ||
      previous.total != current.total,
  builder: (context, state) => Text(
    state is TransactionsLoaded ? state.total.toString() : '',
  ),
)
```

**الفرق بين `buildWhen` و `BlocSelector`:**
- `buildWhen` — تتحكم في *متى* يُعاد البناء، لكن الـ builder يستقبل الـ state كاملاً
- `BlocSelector` — يعيد البناء فقط عند تغيّر القيمة المحددة، والـ builder يستقبل القيمة مباشرة (أنظف للقيم المفردة)

**استخدم `context.select` داخل الـ widgets للقيم المفردة:**

```dart
final total = context.select<TransactionsCubit, double>(
  (cubit) => cubit.state is TransactionsLoaded
      ? (cubit.state as TransactionsLoaded).total
      : 0.0,
);
```

### قواعد بناء الـ Widgets

- **قسّم الشاشة إلى widgets صغيرة** — كل widget يستمع فقط للجزء الذي يعرضه
- **لا تضع `BlocBuilder` على مستوى الشاشة كلها** إلا للحالات الهيكلية (loading/error)
- **استخدم `const` constructor** لأي widget لا يعتمد على state أو props متغيرة
- **لا تبني widgets داخل دوال** — استخدم classes منفصلة حتى يعمل `const` بشكل صحيح

```dart
// غلط
Widget build(context) => Column(children: [_buildHeader(), _buildList()]);

// صح
Widget build(context) => const Column(children: [_TransactionHeader(), _TransactionList()]);
```

### قوائم الأداء العالي

- **استخدم `ListView.builder`** دائماً للقوائم — لا تبني القائمة كاملة مرة واحدة
- **استخدم `itemExtent`** إذا كانت عناصر القائمة بنفس الارتفاع — يتجنب حسابات layout
- **لا تضع `ListView` داخل `Column` بدون `shrinkWrap`** — يسبب overflow أو حسابات زائدة
- **استخدم `RepaintBoundary`** حول widgets تتحرك أو تتغير باستمرار لعزل الـ repaint

```dart
ListView.builder(
  itemCount: items.length,
  itemExtent: 72.0, // ارتفاع ثابت = أداء أفضل
  itemBuilder: (context, i) => TransactionTile(item: items[i]),
)
```

### إدارة الذاكرة

- **لا تحتفظ بقوائم كبيرة في الـ state** — استخدم pagination أو lazy loading
- **أغلق الـ controllers في `dispose()`** — `TextEditingController`, `ScrollController`, `AnimationController`
- **لا تعمل `setState` أو `emit` داخل `initState` مباشرة** — استخدم `addPostFrameCallback`
- **استخدم `AutomaticKeepAliveClientMixin` بحذر** — فقط للشاشات التي يكون إعادة بنائها مكلفاً جداً

### حجم التطبيق

- **لا تضيف packages** إلا إذا كانت ضرورية — كل package تزيد حجم الـ APK
- **استخدم صور `WebP` أو `SVG`** بدل `PNG` حيث أمكن
- **فعّل `--split-per-abi`** عند البناء للـ Android للحصول على APK مخصص لكل معالج
- **استخدم `flutter build apk --obfuscate --split-debug-info`** في الإنتاج

### قواعد Images & Assets

- **لا تحمّل صور من الشبكة بدون cache** — استخدم `cached_network_image` إذا احتجت
- **حدد `width` و `height`** دائماً للصور لتجنب layout shifts
- **استخدم `AssetImage` بدل `NetworkImage`** للأصول الثابتة

---

## قواعد عامة

1. **لا تعليقات** إلا إذا كان السبب غير واضح من الكود
2. **لا error handling زائد** — فقط try/catch في الـ repository
3. **اللغة العربية** في كل النصوص التي يراها المستخدم
4. **RTL** دائماً — `Directionality(textDirection: TextDirection.rtl, ...)`
5. **لا تضيف features** غير مطلوبة
6. **الأداء أولاً** — قبل كتابة أي widget فكر: هل سيُعاد بناؤه أكثر من اللازم؟

---

## عند إضافة feature جديدة

1. إنشاء المجلد: `lib/features/<name>/data/`, `domain/`, `presentation/`
2. كتابة: `<name>_ob.dart` ← `<name>_entity.dart` ← `<name>_repository.dart` ← `<name>_repository_impl.dart` ← `<name>_local_datasource.dart` ← `<name>_usecases.dart` ← `<name>_cubit.dart` ← `<name>_page.dart`
3. تسجيل كل شيء في `injection_container.dart` بالترتيب: datasource → repository → usecases → cubit (factory)
4. إضافة الـ cubit في `AppShell._buildPage()`
5. **قسّم الشاشة لـ widgets صغيرة** — كل widget يستمع بـ `BlocSelector` فقط للجزء الذي يحتاجه

---

## الـ Packages الأساسية

| Package | الاستخدام |
|---------|-----------|
| `flutter_bloc` | State management (Cubit) |
| `objectbox` | قاعدة البيانات المحلية |
| `get_it` | Dependency Injection |
| `dartz` | Either (functional error handling) |
| `equatable` | مقارنة الـ states/entities |
| `shared_preferences` | إعدادات بسيطة (theme, font scale, date range) |
| `flutter_screenutil` | Responsive sizing — `.w` `.h` `.r` `.sp` |
| `adhan` | حساب أوقات الصلاة (pure Dart) |
| `geolocator` | GPS للموقع |
| `flutter_compass` | حساس البوصلة للقبلة |
| `flutter_local_notifications` | تنبيهات أوقات الصلاة (AlarmManager — يعمل مع إغلاق التطبيق) |
| `workmanager` | إعادة جدولة الصلوات يومياً في الخلفية |
| `audioplayers` | معاينة أصوات الأذان في شاشة الإعدادات |
| `google_fonts` | خط Cairo للـ UI — Scheherazade New لنص القرآن |
| `intl` | تنسيق التاريخ والأرقام |
