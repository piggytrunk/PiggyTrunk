import 'package:flutter/material.dart';
import '../services/locale_provider.dart';

class AppStrings {
  final String locale;

  AppStrings(this.locale);

  static AppStrings of(BuildContext context) {
    final loc = SettingsProvider.of(context)?.currentLocale ?? 'en';
    return AppStrings(loc);
  }

  bool get isFilipino => locale == 'fil';

  // ================= Common / Navigation =================
  String get dashboard => isFilipino ? 'Dashboard' : 'Dashboard';
  String get request => isFilipino ? 'Kahilingan' : 'Request';
  String get hogs => isFilipino ? 'Mga Baboy' : 'Hogs';
  String get profile => isFilipino ? 'Profile' : 'Profile';
  String get signOut => isFilipino ? 'Mag-sign Out' : 'Sign Out';
  String get cancel => isFilipino ? 'Kanselahin' : 'Cancel';
  String get confirm => isFilipino ? 'Kumpirmahin' : 'Confirm';
  String get edit => isFilipino ? 'I-edit' : 'Edit';
  String get reset => isFilipino ? 'I-reset' : 'Reset';
  String get close => isFilipino ? 'Isara' : 'Close';
  String get save => isFilipino ? 'I-save' : 'Save';
  String get viewAll => isFilipino ? 'Tingnan Lahat' : 'View All';
  String get viewBreakdown =>
      isFilipino ? 'Tingnan ang Detalye' : 'View Breakdown';

  // ================= Bottom Navigation Bar =================
  String get navDashboard => isFilipino ? 'DASHBOARD' : 'DASHBOARD';
  String get navRequest => isFilipino ? 'KAHILINGAN' : 'REQUEST';
  String get navHogs => isFilipino ? 'MGA BABOY' : 'HOGS';
  String get navProfile => isFilipino ? 'PROFILE' : 'PROFILE';
  String get navHome => isFilipino ? 'TAHANAN' : 'HOME';
  String get navInventory => isFilipino ? 'IMBENTARYO' : 'INVENTORY';
  String get navPOS => isFilipino ? 'POS' : 'POS';

  // ─── Time-based greeting ────────────────────────────────────────────────
  // Automatically detects device local time — no hardcoding.
  // 12:00 AM – 11:59 AM  → Morning  (kasama ang 1AM, 2AM, 3AM = umaga na)
  // 12:00 PM – 5:59 PM   → Afternoon
  // 6:00 PM  – 11:59 PM  → Evening
  String get helloGreeting {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return isFilipino ? 'Magandang Umaga,' : 'Good Morning,';
    } else if (hour < 18) {
      return isFilipino ? 'Magandang Hapon,' : 'Good Afternoon,';
    } else {
      return isFilipino ? 'Magandang Gabi,' : 'Good Evening,';
    }
  }

  // ================= Dashboard / Home Tab =================
  String get totalCurrentInvestment =>
      isFilipino ? 'KABUUANG KASALUKUYANG PUHUNAN' : 'TOTAL CURRENT INVESTMENT';
  String get initialCapital =>
      isFilipino ? 'Paunang Puhunan' : 'Initial Capital';
  String get stockRequestsSpend =>
      isFilipino ? 'Ibinawas sa Puhunan' : 'Deducted Supplies';
  String get deductedLabel => isFilipino ? 'Bawas' : 'Deducted';
  String get remainingBudget =>
      isFilipino ? 'Natitirang Puhunan' : 'Remaining Budget';
  String get activeBatch => isFilipino ? 'Aktibong Batch' : 'Active Batch';
  String get quickSummary => isFilipino ? 'Mabilisang Buod' : 'Quick Summary';
  String get totalHogs => isFilipino ? 'Kabuuang Baboy' : 'Total Hogs';
  String get healthy => isFilipino ? 'Malusog' : 'Healthy';
  String get underCare => isFilipino ? 'Nasa Pag-aalaga' : 'Under Care';
  String get pendingRequests =>
      isFilipino ? 'Nakabinbing Kahilingan' : 'Pending Requests';
  String get hogBatchProgress =>
      isFilipino ? 'Progreso ng Batch' : 'Hog Batch Progress';
  String get recentStockRequests =>
      isFilipino ? 'Kamakailang Kahilingan' : 'Recent Stock Requests';
  String get noStockRequestsYet =>
      isFilipino ? 'Wala pang kahilingan sa stock.' : 'No stock requests yet.';
  String get noActiveBatchNotice => isFilipino
      ? 'Wala pang aktibong batch na nakatalaga.'
      : 'No active batch assigned yet.';
  String get investmentBreakdownTitle =>
      isFilipino ? 'Detalye ng Puhunan' : 'Investment Breakdown';

  // ================= Stock Requests Tab =================
  String get stockRequestsTitle =>
      isFilipino ? 'Mga Kahilingan sa Stock' : 'Stock Requests';
  String get stockRequestsSubtitle => isFilipino
      ? 'Subaybayan at pamahalaan ang iyong mga kahilingan sa pakain at gamot'
      : 'Track and manage your feeds, medicines, and equipment requests';
  String get newRequestButton => isFilipino ? '+ Humiling' : '+ Request';
  String get requestHistory => isFilipino ? 'Kasaysayan' : 'History';
  String get newStockRequest =>
      isFilipino ? 'Bagong Kahilingan' : 'New Stock Request';
  String get searchRequests =>
      isFilipino ? 'Maghanap ng kahilingan...' : 'Search requests...';
  String get selectProduct =>
      isFilipino ? 'Pumili ng Produkto' : 'Select Product';
  String get quantity => isFilipino ? 'Dami' : 'Quantity';
  String get notesOrReason =>
      isFilipino ? 'Mga Tala / Dahilan' : 'Notes / Reason';
  String get submitRequest =>
      isFilipino ? 'Isumite ang Kahilingan' : 'Submit Request';
  String get filterAll => isFilipino ? 'Lahat' : 'All';
  String get filterPending => isFilipino ? 'Nakabinbin' : 'Pending';
  String get filterApproved => isFilipino ? 'Aprubado' : 'Approved';
  String get filterDistributed => isFilipino ? 'Naipamahagi' : 'Distributed';
  String get filterRejected => isFilipino ? 'Tinanggihan' : 'Rejected';

  // ================= Request Form Strings =================
  String get requestSuppliesTitle =>
      isFilipino ? 'Humiling ng Supplies' : 'Request Supplies';
  String get selectBatchHogs =>
      isFilipino ? 'Piliin ang Batch / Alagang Baboy' : 'Select Batch / Hogs';
  String get noActiveBatchAssigned => isFilipino
      ? 'Walang aktibong batch na nakatalaga.'
      : 'No active batch assigned.';
  String get selectCategory =>
      isFilipino ? 'Piliin ang Kategorya' : 'Select Category';
  String get feedsLabel => 'Feeds';
  String get feedsSublabel => isFilipino ? 'Pagkain' : 'Feeds';
  String get medicineLabel => 'Medicine';
  String get medicineSublabel => isFilipino ? 'Gamot' : 'Medicine';
  String get vitaminsLabel => 'Vitamins';
  String get vitaminsSublabel => isFilipino ? 'Bitamina' : 'Vitamins';
  String get quantityBagsPcs =>
      isFilipino ? 'Dami (Sako / Piraso)' : 'Quantity (Bags / Pieces)';
  String get feedTypeTitle => isFilipino ? 'Uri ng Feeds' : 'Feed Type';
  String get notesTitle => isFilipino
      ? 'Karagdagang Impormasyon / Tala'
      : 'Additional Information / Notes';
  String get notesHint => isFilipino
      ? 'Ipaliwanag kung para saan ito...'
      : 'Explain the purpose of this request...';
  String get confirmRequestButton =>
      isFilipino ? 'Kumpirmahin ang Kahilingan' : 'Confirm Request';
  String get pleaseSelectBatch => isFilipino
      ? 'Paki-pili ang assignment batch para sa kahilingan.'
      : 'Please select an assigned batch.';
  String get pleaseEnterQuantity => isFilipino
      ? 'Paki-lagay ang dami ng item na hihilingin (dapat higit sa 0).'
      : 'Please enter a valid quantity (must be greater than 0).';
  String get requestSuccessToast => isFilipino
      ? 'Matagumpay na naipadala ang iyong kahilingan!'
      : 'Stock request submitted successfully!';
  String get requestFailedToast => isFilipino
      ? 'Nagka-problema sa pagpapadala ng kahilingan.'
      : 'Failed to submit request.';
  String get selectCategoriesHint => isFilipino
      ? 'Pumili ng isa o higit pang kategorya na kailangan'
      : 'Select one or more categories needed';
  String get requestSummaryTitle =>
      isFilipino ? 'Buod ng Kahilingan' : 'Request Summary';
  String get noCategorySelectedPrompt => isFilipino
      ? 'Pumili ng kahit isang kategorya sa itaas upang ilagay ang dami.'
      : 'Select at least one category above to configure quantities.';
  String get brandOrDetailLabel => isFilipino
      ? 'Brand o Detalye ng Feeds (Opsyonal)'
      : 'Brand or Feed Details (Optional)';
  String get specificFeedsLabel => isFilipino
      ? 'Tiyak na Uri / Brand ng Feeds'
      : 'Specific Feed Type / Brand';
  String get specificFeedsHint => isFilipino
      ? 'hal. Booster, Starter, Grower, B-MEG...'
      : 'e.g., Booster, Starter, Grower, B-MEG...';
  String get specificMedicineLabel => isFilipino
      ? 'Tiyak na Pangalan / Uri ng Gamot'
      : 'Specific Medicine Name / Details';
  String get specificMedicineHint => isFilipino
      ? 'hal. Amoxicillin, Dewormer, Iron, Penicillin...'
      : 'e.g., Amoxicillin, Dewormer, Iron, Penicillin...';
  String get specificVitaminsLabel => isFilipino
      ? 'Tiyak na Pangalan / Uri ng Bitamina'
      : 'Specific Vitamin Name / Details';
  String get specificVitaminsHint => isFilipino
      ? 'hal. B-Complex, Electrolytes, Multivitamins...'
      : 'e.g., B-Complex, Electrolytes, Multivitamins...';
  String get generalNotesSubtitle => isFilipino
      ? 'Pangkalahatang mensahe o tagubilin para sa admin'
      : 'General message or instructions for the admin';
  String get batchRequiredTitle =>
      isFilipino ? 'Kailangan ng Aktibong Batch' : 'Active Batch Required';
  String get batchRequiredMessage => isFilipino
      ? 'Hindi pa makakahiling ng supplies sa ngayon dahil wala ka pang aktibong batch ng alagang baboy na nakatalaga sa iyong account.'
      : 'You cannot request supplies yet because your account does not have an active assigned hog batch.';
  String get batchRequiredHint => isFilipino
      ? 'Kailangan munang ma-assign sa batch upang makapag-request.'
      : 'Active batch assignment required before submitting requests.';
  String get batchRequiredContactAdmin => isFilipino
      ? 'Makipag-ugnayan sa Farm Admin upang maitalaga ang iyong batch.'
      : 'Please coordinate with your Farm Admin to assign your active batch.';
  String get gotItButton => isFilipino ? 'Naintindihan' : 'Got it';

  // ================= Notifications Drawer =================
  String get notificationsTitle => isFilipino ? 'Mga Abiso' : 'Notifications';
  String get notificationsSubtitle =>
      isFilipino ? 'Mga live na update at alerto' : 'Live updates and alerts';
  String get markAllRead => isFilipino ? 'Markahan na Nabasa' : 'Mark as Read';
  String get noNotifications =>
      isFilipino ? 'Walang Notipikasyon' : 'No Notifications';
  String get noNotificationsSubtitle => isFilipino
      ? 'Lalabas dito ang mga bagong update.'
      : 'You\'re all caught up! New updates will show here.';
  String get allCaughtUp =>
      isFilipino ? 'Lahat ay Nabasa Na!' : 'All Caught Up!';
  String get allCaughtUpSubtitle => isFilipino
      ? 'Walang aktibong alerto sa stock o nakabinbing kahilingan sa ngayon.'
      : 'No active stock alerts or pending requests at this time.';
  String get noHistoryRecorded =>
      isFilipino ? 'Walang Kasaysayan' : 'No History Recorded';
  String get noHistorySubtitle => isFilipino
      ? 'Wala pang kasaysayan ng mga abiso na naitala.'
      : 'No notification history recorded yet.';
  String get viewNotificationHistory =>
      isFilipino ? 'Tingnan ang Kasaysayan' : 'View Notification History';
  String get tabActive => isFilipino ? 'Aktibo' : 'Active';
  String get tabRequests => isFilipino ? 'Kahilingan' : 'Requests';
  String get tabStock => isFilipino ? 'Imbentaryo' : 'Stock';
  String get tabHistory => isFilipino ? 'Kasaysayan' : 'History';
  String get tabApproved => isFilipino ? 'Aprubado' : 'Approved';
  String get tabHogUpdates => isFilipino ? 'Mga Baboy' : 'Hog Updates';
  String get tabInvestments => isFilipino ? 'Puhunan' : 'Investments';
  String get tabStageProgress => isFilipino ? 'Progreso' : 'Stage Progress';
  String get allNotificationsMarkedRead => isFilipino
      ? 'Lahat ng abiso ay minarkahang nabasa na'
      : 'All notifications marked as read';
  String get reviewRequest =>
      isFilipino ? 'Suriin ang Kahilingan' : 'Review Request';
  String get restockItem => isFilipino ? 'Mag-restock' : 'Restock Item';
  String get viewReceipt => isFilipino ? 'Tingnan ang Resibo' : 'View Receipt';

  // ================= Hogs Tab & Reports =================
  String get myHogsTitle => isFilipino ? 'Aking mga Baboy' : 'My Hogs';
  String get myHogsSubtitle => isFilipino
      ? 'Subaybayan ang kalusugan ng mga alaga'
      : 'Monitor daily health and status';
  String get healthReportsActivity =>
      isFilipino ? 'Mga Ulat sa Kalusugan' : 'Health Reports Activity';
  String get addReportButton => isFilipino ? 'Mag-ulat' : 'Add Report';
  String get submitReportButton =>
      isFilipino ? 'Magsumite ng Ulat' : 'Submit Report';
  String get searchHog =>
      isFilipino ? 'Maghanap ng tag number...' : 'Search tag number...';
  String get statusHealthy => isFilipino ? 'Malusog' : 'Healthy';
  String get statusSick => isFilipino ? 'May Sakit' : 'Sick';
  String get statusObservation =>
      isFilipino ? 'Obserbasyon' : 'Under Observation';
  String get statusQuarantine => isFilipino ? 'Kuwarentenas' : 'Quarantine';
  String get statusDeceased => isFilipino ? 'Namatay' : 'Deceased';
  String get statusSold => isFilipino ? 'Naibenta' : 'Sold';
  String get noHogsFound =>
      isFilipino ? 'Walang nahanap na baboy.' : 'No hogs found.';
  String get noHogsSubtitle => isFilipino
      ? 'Walang nakatalagang baboy sa batch.'
      : 'No hogs assigned to this batch.';
  String get noHealthReports =>
      isFilipino ? 'Walang ulat sa kalusugan.' : 'No health reports yet.';
  String get noHealthReportsSubtitle => isFilipino
      ? 'Lahat ng alaga ay malusog.'
      : 'All hogs are in healthy condition.';
  String get healthReportTitle =>
      isFilipino ? 'Ulat sa Kalusugan' : 'Health Report';
  String get healthReportSubtitle => isFilipino
      ? 'Mag-ulat ng obserbasyon sa kalusugan ng baboy'
      : 'Report observation on hog health';
  String get selectHog => isFilipino ? 'Piliin ang Baboy' : 'Select Hog';
  String get noHogsAssignedCurrently => isFilipino
      ? 'Walang nakatalagang baboy sa kasalukuyan.'
      : 'No hogs currently assigned.';
  String get reportType => isFilipino ? 'Uri ng Ulat' : 'Report Type';
  String get foodPoisoning =>
      isFilipino ? 'Pagkalason sa Pagkain' : 'Food Poisoning';
  String get fever => isFilipino ? 'Lagnat' : 'Fever';
  String get diarrhea => isFilipino ? 'Pagtatae' : 'Diarrhea';
  String get injury => isFilipino ? 'Sugat' : 'Injury';
  String get deceasedReport => isFilipino ? 'Namatay' : 'Deceased';
  String get additionalDetails =>
      isFilipino ? 'Karagdagang Detalye' : 'Additional Details';
  String get healthNotesHint => isFilipino
      ? 'Isulat ang obserbasyon sa baboy...'
      : 'Write observation about the hog...';
  String get submitReportAction =>
      isFilipino ? 'Isumite ang Ulat' : 'Submit Report';
  String get hogReportSubmittedSuccess => isFilipino
      ? 'Matagumpay na naipadala ang Hog Report!'
      : 'Hog report submitted successfully!';
  String stageUpdatedSuccess(String stage) => isFilipino
      ? 'Matagumpay na nailipat ang stage sa $stage!'
      : 'Successfully updated stage to $stage!';
  String get profilePictureUpdatedSuccess => isFilipino
      ? 'Matagumpay na na-update ang inyong profile picture!'
      : 'Profile picture updated successfully!';
  String get profileRestoredDefaultSuccess => isFilipino
      ? 'Matagumpay na naibalik sa default ang inyong profile!'
      : 'Profile successfully restored to default!';
  String get resetProfileConfirmTitle =>
      isFilipino ? 'I-reset ang Profile?' : 'Reset Profile Picture?';
  String get resetProfileConfirmBody => isFilipino
      ? 'Sigurado ka bang nais mong ibalik sa default ang iyong profile picture at mga setting?'
      : 'Are you sure you want to restore your profile picture and settings to default?';
  String get resetAccountDetailsTitle => isFilipino
      ? 'I-reset ang mga Detalye ng Account?'
      : 'Reset Account Details?';
  String get resetAccountDetailsBody => isFilipino
      ? 'Sigurado ka bang nais mong ibalik sa default ang lahat ng detalye ng iyong account? Ibabalik nito ang iyong pangalan sa rehistradong pangalan, tatanggalin ang custom na telepono at address, at ibabalik ang default na avatar.'
      : 'Are you sure you want to restore all your account details to default? This will revert your name back to your registered name, clear custom phone and address information, and restore the default avatar.';
  String get accountDetailsRestoredSuccess => isFilipino
      ? 'Matagumpay na naibalik sa default ang mga detalye ng account!'
      : 'Account details restored to default successfully!';
  String get changePhotoOption =>
      isFilipino ? 'Larawan ng Profile' : 'Profile Photo';
  String get uploadNewPhoto =>
      isFilipino ? 'Mag-upload ng Bagong Larawan' : 'Upload New Photo';
  String get restoreDefaultLogo =>
      isFilipino ? 'Ibalik ang Default na Logo' : 'Restore Default Logo';
  String get profilePictureUploadFailed => isFilipino
      ? 'Hindi na-upload ang larawan ng profile. Pakisubukang muli.'
      : 'Failed to upload profile photo. Please try again.';
  String get profilePictureUploadOffline => isFilipino
      ? 'Kailangan ng koneksyon sa internet upang mag-upload ng profile photo.'
      : 'Internet connection is required to upload profile photo.';
  String get offlineNotificationTitle =>
      isFilipino ? 'Walang Koneksyon sa Internet' : 'No Internet Connection';
  String get no => isFilipino ? 'Hindi' : 'No';
  String get yesReset => isFilipino ? 'Oo, I-reset' : 'Yes, Reset';
  String get noWeightRecorded =>
      isFilipino ? 'Walang tala ng timbang' : 'No weight recorded';
  String get noHogsAssignedNotice => isFilipino
      ? 'Walang nakatalagang alagang baboy.'
      : 'No hogs assigned yet.';
  String get farmAdminAssignNotice => isFilipino
      ? 'I-aassign ng Farm Admin ang iyong batch dito.'
      : 'Farm Admin will assign your batch here.';

  // ================= Stage Progression =================
  String get stageProgressionTitle =>
      isFilipino ? 'Progreso ng Yugto' : 'Stage Progression';
  String advanceStagePrompt(String targetStage) => isFilipino
      ? 'Nais mo bang i-advance ang growth stage ng batch patungong $targetStage?'
      : 'Do you want to advance the batch growth stage to $targetStage?';
  String advanceHogStagePrompt(String hogName, String targetStage) => isFilipino
      ? 'Nais mo bang ilipat ang yugto ng pakain para sa $hogName patungong $targetStage?'
      : 'Do you want to advance the feed stage for $hogName to $targetStage?';
  String hogStageUpdatedSuccess(String hogName, String targetStage) =>
      isFilipino
      ? 'Matagumpay na nailipat ang yugto ng $hogName sa $targetStage!'
      : 'Successfully updated feed stage of $hogName to $targetStage!';
  String get fatteningTag => isFilipino ? 'Pagpapataba' : 'Fattening';
  String get sowBreedTag => isFilipino ? 'Palahi / Sow' : 'Sow / Breeding';
  String get feedStageLabel => isFilipino ? 'Yugto ng Pakain' : 'Feed Stage';
  String get hogDetailsTitle => isFilipino ? 'Detalye ng Baboy' : 'Hog Details';
  String get update => isFilipino ? 'I-update' : 'Update';

  // ================= Edit Profile Modal =================
  String get editProfileTitle =>
      isFilipino ? 'I-edit ang Profile' : 'Edit Profile';
  String get fullName => isFilipino ? 'Buong Pangalan' : 'Full Name';
  String get firstNameLabel => isFilipino ? 'Unang Pangalan' : 'First Name';
  String get lastNameLabel => isFilipino ? 'Apelyido' : 'Last Name';
  String get middleInitialLabel =>
      isFilipino ? 'Gitnang Inisyal' : 'Middle Initial';
  String get optionalLabel => isFilipino ? '(Opsyonal)' : '(Optional)';
  String get phoneHelperNotice =>
      isFilipino ? '09XXXXXXXXX (11 digits)' : '09XXXXXXXXX (11 digits)';
  String get firstNameRequired =>
      isFilipino ? 'Kailangan ang unang pangalan.' : 'First name is required.';
  String get lastNameRequired =>
      isFilipino ? 'Kailangan ang apelyido.' : 'Last name is required.';
  String get nameInvalidCharacters => isFilipino
      ? 'Hindi pinapayagan ang numero o simbolo.'
      : 'Numbers and symbols are not allowed.';
  String get phoneMustStart09 => isFilipino
      ? 'Dapat magsimula sa 09 ang numero.'
      : 'Must start with 09 (e.g. 09XXXXXXXXX).';
  String get phoneMustBe11Digits => isFilipino
      ? 'Dapat eksaktong 11-digit ang numero.'
      : 'Must be exactly 11 digits.';
  String get enterFullNameHint =>
      isFilipino ? 'Ilagay ang inyong buong pangalan' : 'Enter your full name';
  String get phoneLabel => isFilipino ? 'Numero ng Telepono' : 'Phone Number';
  String get numbersOnlyNotice =>
      isFilipino ? 'Numero lamang (11 digits)' : 'Numbers only (11 digits)';
  String get address => isFilipino ? 'Address' : 'Address';
  String get enterAddressHint => isFilipino
      ? 'Ilagay ang inyong kumpletong address'
      : 'Enter your complete address';
  String get saveChanges =>
      isFilipino ? 'I-save ang Pagbabago' : 'Save Changes';
  String get pleaseEnterFullName => isFilipino
      ? 'Mangyaring ilagay ang buong pangalan.'
      : 'Please enter your full name.';
  String get invalidPhoneNumber => isFilipino
      ? 'Dapat ay 11-digit na numero at nagsisimula sa 09.'
      : 'Must be an 11-digit number starting with 09.';
  String get profileUpdateSuccess => isFilipino
      ? 'Matagumpay na na-update ang iyong profile!'
      : 'Profile updated successfully!';
  String get profileUpdateFailed =>
      isFilipino ? 'Hindi na-update ang profile.' : 'Failed to update profile.';
  String get pressBackAgainToExit => isFilipino
      ? 'Pindutin ulit ang Back button upang isara ang app.'
      : 'Press Back button again to exit the app.';

  // ================= Cashier Module Strings =================
  String get cashierGreeting => helloGreeting;

  String get cashierRole =>
      isFilipino ? 'Staff ng Tindahan / POS' : 'Cashier Staff';
  String get todaySales =>
      isFilipino ? 'Kabuuang Benta Ngayong Araw' : 'Today\'s Total Sales';
  String get todayTransactions =>
      isFilipino ? 'Mga Transaksyon' : 'Transactions';
  String get inStockItems =>
      isFilipino ? 'May Stock na Item' : 'In Stock Items';
  String get lowStockAlerts =>
      isFilipino ? 'Babala sa Mababang Stock' : 'Low Stock Alerts';
  String get pendingHogRequests =>
      isFilipino ? 'Nakabinbing Kahilingan' : 'Pending Requests';
  String get quickActions => isFilipino ? 'Mabilisang Aksyon' : 'Quick Actions';
  String get openPOS => isFilipino ? 'Buksan ang POS' : 'Open POS';
  String get stockAllocation =>
      isFilipino ? 'Pamamahagi ng Stock' : 'Stock Allocation';
  String get manageInventory =>
      isFilipino ? 'Pamahalaan ang Imbentaryo' : 'Manage Inventory';
  String get fastMovingProducts =>
      isFilipino ? 'Mabilis Mabentang Produkto' : 'Fast-Moving Products';
  String get recentSalesActivity =>
      isFilipino ? 'Kamakailang Benta' : 'Recent Sales Activity';
  String get viewAllSales =>
      isFilipino ? 'Tingnan Lahat ng Resibo' : 'View All Receipts';
  String get inventoryTitle =>
      isFilipino ? 'Imbentaryo ng Tindahan' : 'Store Inventory';
  String get inventorySubtitle => isFilipino
      ? 'Subaybayan at pamahalaan ang mga stock'
      : 'Track and manage supplies & feeds';
  String get posRegister =>
      isFilipino ? 'Punto ng Pagbenta (POS)' : 'Point of Sale (POS)';
  String get searchProducts => isFilipino
      ? 'Maghanap ng produkto...'
      : 'Search products by name or category...';
  String get cartSummary => isFilipino ? 'Buod ng Cart' : 'Cart Summary';
  String get checkout => isFilipino ? 'Magbayad' : 'Checkout';
  String get clearCart => isFilipino ? 'Linisin ang Cart' : 'Clear Cart';
  String get emptyCart =>
      isFilipino ? 'Walang laman ang cart' : 'Your cart is empty';
  String get addToCart => isFilipino ? 'Idagdag sa Cart' : 'Add to Cart';

  // ================= Profile Tab =================
  String get hogRaiserRole => isFilipino ? 'Tagapag-alaga' : 'Hog Raiser';
  String get accountDetails =>
      isFilipino ? 'Impormasyon ng Account' : 'Account Details';
  String get emailAddress => isFilipino ? 'Email Address' : 'Email Address';
  String get phoneNumber => isFilipino ? 'Numero ng Telepono' : 'Phone Number';
  String get farmAddress => isFilipino ? 'Address ng Bukid' : 'Farm Address';
  String get branchAddress =>
      isFilipino ? 'Address ng Tindahan / Sangay' : 'Store / Branch Address';
  String get pigTypeAssignment =>
      isFilipino ? 'Uri ng Alagang Baboy' : 'Pig Type Assignment';
  String get currentFeedsStage =>
      isFilipino ? 'Kasalukuyang Stage ng Pagkain' : 'Current Feeds Stage';
  String get systemAccess => isFilipino ? 'Antas sa Sistema' : 'System Access';
  String get accountStatus =>
      isFilipino ? 'Katayuan ng Account' : 'Account Status';
  String get activeStatus => isFilipino ? 'Aktibo' : 'Active';
  String get unassigned => isFilipino ? 'Hindi pa naitatalaga' : 'Unassigned';
  String get notSet => isFilipino ? 'Hindi nakatakda' : 'Not set';

  // ================= Location & Address Action Strings =================
  String get actionNeeded => isFilipino ? 'Kailangan I-set' : 'Action Needed';
  String get farmLocationMissing =>
      isFilipino ? 'Kulang ang Address ng Bukid' : 'Farm Location Missing';
  String get farmLocationMissingDesc => isFilipino
      ? 'Kailangan ng admin ang address ng bukid para sa pag-verify ng iyong account.'
      : 'Please set your farm address for admin verification.';
  String get locationNotSetTap => isFilipino
      ? 'Wala pang address • I-tap para i-set'
      : 'Location not set • Tap to detect or enter';
  String get autoDetectLocation =>
      isFilipino ? 'I-detect ang Lokasyon' : 'Auto-Detect Location';
  String get detectingGps =>
      isFilipino ? 'Dine-detect ang GPS...' : 'Detecting GPS...';
  String get locationDisabledTitle =>
      isFilipino ? 'Naka-off ang Lokasyon' : 'Location Permission Disabled';
  String get locationDisabledDesc => isFilipino
      ? 'Naka-off ang location access ng Piggy Trunk sa mga setting ng telepono. Nais mo bang buksan ang App Settings para i-on ito?'
      : 'Location access for Piggy Trunk is turned off in your phone settings. Would you like to open App Settings to allow it?';
  String get openSettings =>
      isFilipino ? 'Buksan ang Settings' : 'Open Settings';
  String get locationSavedToast =>
      isFilipino ? 'Nai-save ang lokasyon:' : 'Location saved:';
  String get locationDetectedToast =>
      isFilipino ? 'Natukoy ang lokasyon:' : 'Location detected:';
  String get tapToDetectGpsAddress => isFilipino
      ? 'I-tap upang i-detect ang lokasyon gamit ang GPS'
      : 'Tap to auto-detect location via GPS';
  String get internetRequiredForGpsAddress => isFilipino
      ? 'Kailangan ng internet connection para makuha ang address mula sa GPS. Mangyaring kumonekta sa Wi-Fi/mobile data o manu-manong i-type ang iyong address.'
      : 'An active internet connection is required to look up your street address from GPS. Please connect to Wi-Fi/mobile data or type your address manually.';

  // ================= Settings / Language =================
  String get settings => isFilipino ? 'Mga Setting' : 'Settings';
  String get languagePreference =>
      isFilipino ? 'Piniling Wika' : 'Language Preference';
  String get languageSubtitle => isFilipino
      ? 'Piliin ang nais mong wika sa app'
      : 'Choose your preferred app language';
  String get english => 'English';
  String get filipino => 'Filipino';

  // ================= Partner Investor Module Strings =================
  String get partnerGreeting => helloGreeting;

  String get partnerRole =>
      isFilipino ? 'Kasosyong Mamumuhunan' : 'Partner Investor';
  String get portfolioOverview =>
      isFilipino ? 'Portfolio' : 'Portfolio Overview';
  String get totalInvested =>
      isFilipino ? 'KABUUANG NAIPUHUNAN' : 'TOTAL INVESTED';
  String get activeProjects =>
      isFilipino ? 'MGA AKTIBONG PROYEKTO' : 'ACTIVE PROJECTS';
  String get activeRaisers =>
      isFilipino ? 'Aktibong Tagapag-alaga' : 'Active Raisers';
  String get hogsFunded => isFilipino ? 'Pinondohang Baboy' : 'Hogs Funded';
  String get browseOpportunities =>
      isFilipino ? 'Mag-browse ng Oportunidad' : 'Browse Opportunities';
  String get recentActivities =>
      isFilipino ? 'Kamakailang Aktibidad' : 'Recent Activities';
  String get seeAll => isFilipino ? 'Tingnan Lahat' : 'See All';
  String get noActivitiesYet => isFilipino
      ? 'Wala pang naitalang aktibidad.'
      : 'No activities recorded yet.';
  String get investmentOpportunities =>
      isFilipino ? 'Mga Oportunidad sa Puhunan' : 'Investment Opportunities';
  String get availableBatchesSubtitle => isFilipino
      ? 'Tingnan at pondohan ang mga aktibong batch ng baboy'
      : 'View and fund active hog batches';
  String get fundBatch => isFilipino ? 'Pondohan ang Batch' : 'Fund Batch';
  String get investNow => isFilipino ? 'Mamuhunan Ngayon' : 'Invest Now';
  String get batchProgress =>
      isFilipino ? 'Progreso ng Batch' : 'Batch Progress';
  String get batchDetails => isFilipino ? 'Detalye ng Batch' : 'Batch Details';
  String get assignedRaiser =>
      isFilipino ? 'Nakatalagang Tagapag-alaga' : 'Assigned Raiser';
  String get targetCapital =>
      isFilipino ? 'Target na Puhunan' : 'Target Capital';
  String get currentFunded =>
      isFilipino ? 'Kasalukuyang Naipon' : 'Current Funded';
  String get projectedROI =>
      isFilipino ? 'Tantiyang Kita (ROI)' : 'Projected ROI';
  String get lifecycleStage =>
      isFilipino ? 'Yugto ng Buhay' : 'Lifecycle Stage';
  String get hogCount => isFilipino ? 'Bilang ng Baboy' : 'Hog Count';
  String get searchBatches => isFilipino
      ? 'Maghanap ng batch o tagapag-alaga...'
      : 'Search batch or raiser...';
  String get allBatches => isFilipino ? 'Lahat ng Batch' : 'All Batches';
  String get myInvestments =>
      isFilipino ? 'Aking mga Puhunan' : 'My Investments';
  String get myInvestmentsSubtitle => isFilipino
      ? 'Subaybayan ang iyong mga pinondohang proyekto'
      : 'Track your funded projects and returns';
  String get navInvestment => isFilipino ? 'PUHUNAN' : 'INVESTMENT';
  String get navLifecycle => isFilipino ? 'LIFECYCLE' : 'LIFECYCLE';
  String get navActivities => isFilipino ? 'AKTIBIDAD' : 'ACTIVITIES';
  String get raiserReports =>
      isFilipino ? 'Mga Ulat ng Raiser' : 'Raiser Reports';
  String get noReportsYet =>
      isFilipino ? 'Walang Ulat sa Ngayon' : 'No Reports Yet';
  String get noReportsSubtitle => isFilipino
      ? 'Lalabas dito ang mga update ng tagapag-alaga.'
      : 'Updates & logs from your raisers will appear here.';
  String get refreshReports => isFilipino ? 'I-refresh' : 'Refresh Reports';

  // ================= Settings / Theme =================
  String get themePreference => isFilipino ? 'Tema ng App' : 'App Theme';
  String get themeSubtitle => isFilipino
      ? 'Piliin ang light o dark mode'
      : 'Switch between light and dark mode';
  String get lightMode => isFilipino ? 'Light Mode' : 'Light Mode';
  String get darkMode => isFilipino ? 'Dark Mode' : 'Dark Mode';

  // ================= Password & Security =================
  String get passwordAndSecurity =>
      isFilipino ? 'Seguridad at Password' : 'Password & Security';
  String get updatePasswordSubtitle => isFilipino
      ? 'I-update o palitan ang password ng iyong account'
      : 'Update your account password';
  String get changePassword =>
      isFilipino ? 'Palitan ang Password' : 'Change Password';
  String get currentPasswordLabel =>
      isFilipino ? 'Kasalukuyang Password' : 'Current Password';
  String get newPasswordLabel =>
      isFilipino ? 'Bagong Password' : 'New Password';
  String get confirmNewPasswordLabel =>
      isFilipino ? 'Kumpirmahin ang Bagong Password' : 'Confirm New Password';
  String get updatePasswordBtn =>
      isFilipino ? 'I-update ang Password' : 'Update Password';
  String get passwordTooShort => isFilipino
      ? 'Dapat hindi bababa sa 6 na karakter ang bagong password.'
      : 'New password must be at least 6 characters.';
  String get passwordMustContainLetters => isFilipino
      ? 'Dapat mayroong kahit isang titik (a-z, A-Z) ang password.'
      : 'Password must contain at least one letter (a-z, A-Z).';
  String get passwordMustContainNumbers => isFilipino
      ? 'Dapat mayroong kahit isang numero o simbolo (0-9, !@#...) ang password.'
      : 'Password must contain at least one number or symbol (0-9, !@#...).';
  String get passwordWeakNotice => isFilipino
      ? 'Masyadong mahina ang password. Gumamit ng kombinasyon ng mga titik, numero, at simbolo.'
      : 'Password is too weak. Please use a combination of letters, numbers, and symbols.';
  String get passwordsDoNotMatch => isFilipino
      ? 'Hindi magkatugma ang bagong password.'
      : 'New passwords do not match.';
  String get passwordChangedSuccess => isFilipino
      ? 'Matagumpay na napalitan ang iyong password!'
      : 'Password changed successfully!';
  String get googleAccountNotice => isFilipino
      ? 'Naka-link ang account mo gamit ang Google. Maaari kang mag-set ng password dito.'
      : 'Your account is linked with Google. You can set a password here to sign in with email and password as well.';
  String get internetRequiredForProfile => isFilipino
      ? 'Kailangan ng koneksyon sa internet upang i-update ang iyong profile.'
      : 'Internet connection required. Please connect to the internet to update your profile.';
  String get internetRequiredForReset => isFilipino
      ? 'Kailangan ng koneksyon sa internet upang i-reset ang iyong account.'
      : 'Internet connection required. Please connect to the internet to reset your account details.';
  String get internetRequiredForPassword => isFilipino
      ? 'Kailangan ng koneksyon sa internet upang palitan ang iyong password.'
      : 'Internet connection required. Please connect to the internet to change your password.';
  String get connectionLostNotice => isFilipino
      ? 'Nawala ang koneksyon sa internet. Pakisubukang muli.'
      : 'Connection lost. Please check your internet and try again.';

  // ================= App Updates =================
  String get checkForUpdates =>
      isFilipino ? 'Suriin ang mga Update' : 'Check for Updates';
  String get checkForUpdatesSubtitle => isFilipino
      ? 'Tingnan kung may pinakabagong bersyon'
      : 'Check if a newer version is available';
  String get checkingForUpdates =>
      isFilipino ? 'Sinusuri ang mga update...' : 'Checking for updates...';
  String get appUpToDate => isFilipino
      ? 'Nasa pinakabagong bersyon ka na ng Piggy Trunk'
      : "You're using the latest version of Piggy Trunk";
  String get versionLabel => isFilipino ? 'Bersyon' : 'Version';
  String get noInternetForUpdates => isFilipino
      ? 'Walang koneksyon sa internet. Mangyaring kumonekta sa Wi-Fi o mobile data upang suriin ang mga update.'
      : 'No internet connection. Please connect to Wi-Fi or mobile data to check for updates.';
  String get offlineStatus =>
      isFilipino ? 'Offline • I-tap upang subukan muli' : 'Offline • Tap to retry';

  // ================= Auth & Role Selection =================
  String get selectRoleTitle =>
      isFilipino ? 'Mag-sign In sa Piggy Trunk' : 'Sign In to Piggy Trunk';
  String get selectRoleSubtitle => isFilipino
      ? 'Piliin ang uri ng iyong account upang magpatuloy'
      : 'Choose your account role to continue';
  String get hogRaiserOptionTitle =>
      isFilipino ? 'Tagapag-alaga (Hog Raiser)' : 'Hog Raiser';
  String get partnerOptionTitle =>
      isFilipino ? 'Kasosyong Mamumuhunan (Partner)' : 'Partner Investor';
  String get hogRaiserRoleDesc => isFilipino
      ? 'Pamahalaan ang mga batch ng baboy, supplies, at kalusugan'
      : 'Manage livestock, feed supplies, and health updates';
  String get partnerRoleDesc => isFilipino
      ? 'Mamuhunan sa mga batch, portfolio, at subaybayan ang kita'
      : 'Fund hog batches, track your portfolio, and live updates';
  String get alreadyHaveAccountSignIn => isFilipino
      ? 'May account na? Mag-sign In'
      : 'Already have an account? Sign In';
  String signInContinueAs(String roleLabel) => isFilipino
      ? 'Mag-sign in upang magpatuloy bilang $roleLabel'
      : 'Sign in to continue as $roleLabel';

  // ================= Formatting Helpers =================
  String formatStatus(String status) {
    final s = status.toLowerCase().trim();
    if (s == 'pending' || s == 'for_approval') return filterPending;
    if (s == 'approved') return filterApproved;
    if (s == 'distributed') return filterDistributed;
    if (s == 'rejected') return filterRejected;
    if (s == 'healthy') return statusHealthy;
    if (s == 'sick') return statusSick;
    if (s == 'under observation') return statusObservation;
    if (s == 'quarantine') return statusQuarantine;
    if (s == 'deceased' || s == 'dead') return statusDeceased;
    if (s == 'food poisoning') return foodPoisoning;
    if (s == 'fever') return fever;
    if (s == 'diarrhea') return diarrhea;
    if (s == 'injury') return injury;
    return status;
  }

  String formatRelativeTime(dynamic dateVal) {
    if (dateVal == null) return isFilipino ? 'Kani-kanina lang' : 'Recent';
    try {
      final DateTime dt = dateVal is DateTime
          ? dateVal
          : DateTime.parse(dateVal.toString());
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) {
        return isFilipino ? 'Kani-kanina lang' : 'Just now';
      }
      if (diff.inMinutes < 60) {
        return isFilipino
            ? '${diff.inMinutes}m ang nakalipas'
            : '${diff.inMinutes}m ago';
      }
      if (diff.inHours < 24) {
        return isFilipino
            ? '${diff.inHours}h ang nakalipas'
            : '${diff.inHours}h ago';
      }
      if (diff.inDays < 7) {
        return isFilipino
            ? '${diff.inDays}d ang nakalipas'
            : '${diff.inDays}d ago';
      }
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[dt.month - 1]} ${dt.day}';
    } catch (_) {
      return isFilipino ? 'Kamakailan' : 'Recent';
    }
  }
}
