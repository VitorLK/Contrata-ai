import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/network/api_client.dart';
import 'core/router/app_router.dart';
import 'core/router/auth_gate.dart';
import 'core/session/session_manager.dart';
import 'core/theme/app_theme.dart';
import 'services/application_repository.dart';
import 'services/admin_repository.dart';
import 'services/auth_repository.dart';
import 'services/location_repository.dart';
import 'services/professional_repository.dart';
import 'services/service_repository.dart';
import 'services/work_repository.dart';
import 'services/chat_repository.dart';
import 'viewmodels/applications_viewmodel.dart';
import 'viewmodels/admin_viewmodel.dart';
import 'viewmodels/auth_viewmodel.dart';
import 'viewmodels/create_service_viewmodel.dart';
import 'viewmodels/dashboard_viewmodel.dart';
import 'viewmodels/client_work_center_viewmodel.dart';
import 'viewmodels/location_viewmodel.dart';
import 'viewmodels/professional_profile_viewmodel.dart';
import 'viewmodels/professional_public_viewmodel.dart';
import 'viewmodels/professional_search_viewmodel.dart';
import 'viewmodels/service_detail_viewmodel.dart';
import 'viewmodels/services_list_viewmodel.dart';
import 'viewmodels/workday_viewmodel.dart';
import 'viewmodels/chat_viewmodel.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Carrega a sessão salva (token + usuário) antes do primeiro frame, para
  // o AuthGate já abrir na tela certa sem um "flash" da tela de login.
  final sessionManager = SessionManager();
  await sessionManager.load();

  runApp(MyApp(sessionManager: sessionManager));
}

class MyApp extends StatelessWidget {
  final SessionManager sessionManager;

  const MyApp({super.key, required this.sessionManager});

  @override
  Widget build(BuildContext context) {
    final apiClient = ApiClient(sessionManager: sessionManager);
    final authRepository = AuthRepository(apiClient: apiClient);
    final serviceRepository = ServiceRepository(apiClient: apiClient);
    final applicationRepository = ApplicationRepository(apiClient: apiClient);
    final adminRepository = AdminRepository(apiClient: apiClient);
    final professionalRepository = ProfessionalRepository(apiClient: apiClient);
    final workRepository = WorkRepository(apiClient: apiClient);
    final locationRepository = LocationRepository(apiClient: apiClient);
    final chatRepository = ChatRepository(apiClient: apiClient);

    return MultiProvider(
      providers: [
        Provider<SessionManager>.value(value: sessionManager),
        Provider<ServiceRepository>.value(value: serviceRepository),
        Provider<ApplicationRepository>.value(value: applicationRepository),
        Provider<WorkRepository>.value(value: workRepository),
        Provider<AdminRepository>.value(value: adminRepository),
        Provider<ChatRepository>.value(value: chatRepository),
        ChangeNotifierProvider<AdminViewModel>(
          create: (_) => AdminViewModel(adminRepository: adminRepository),
        ),
        ChangeNotifierProvider<AuthViewModel>(
          create: (_) => AuthViewModel(
            authRepository: authRepository,
            sessionManager: sessionManager,
          ),
        ),
        ChangeNotifierProvider<ServicesListViewModel>(
          create: (_) =>
              ServicesListViewModel(serviceRepository: serviceRepository),
        ),
        ChangeNotifierProvider<CreateServiceViewModel>(
          create: (_) =>
              CreateServiceViewModel(serviceRepository: serviceRepository),
        ),
        ChangeNotifierProvider<ServiceDetailViewModel>(
          create: (_) =>
              ServiceDetailViewModel(serviceRepository: serviceRepository),
        ),
        ChangeNotifierProvider<ApplicationsViewModel>(
          create: (_) => ApplicationsViewModel(
            serviceRepository: serviceRepository,
            applicationRepository: applicationRepository,
          ),
        ),
        ChangeNotifierProvider<ProfessionalProfileViewModel>(
          create: (_) => ProfessionalProfileViewModel(
            professionalRepository: professionalRepository,
          ),
        ),
        ChangeNotifierProvider<ProfessionalSearchViewModel>(
          create: (_) => ProfessionalSearchViewModel(
            professionalRepository: professionalRepository,
          ),
        ),
        ChangeNotifierProvider<LocationViewModel>(
          create: (_) =>
              LocationViewModel(locationRepository: locationRepository),
        ),
        ChangeNotifierProvider<ProfessionalPublicViewModel>(
          create: (_) => ProfessionalPublicViewModel(
            professionalRepository: professionalRepository,
          ),
        ),
        ChangeNotifierProvider<DashboardViewModel>(
          create: (_) => DashboardViewModel(
            professionalRepository: professionalRepository,
            workRepository: workRepository,
          ),
        ),
        ChangeNotifierProvider<WorkdayViewModel>(
          create: (_) => WorkdayViewModel(workRepository: workRepository),
        ),
        ChangeNotifierProvider<ClientWorkCenterViewModel>(
          create: (_) =>
              ClientWorkCenterViewModel(workRepository: workRepository),
        ),
        ChangeNotifierProvider<ChatViewModel>(
          create: (_) => ChatViewModel(chatRepository: chatRepository),
        ),
      ],
      child: MaterialApp(
        title: 'Contrata Aí',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routes: AppRouter.routes,
        home: const AuthGate(),
      ),
    );
  }
}
