import 'package:flutter/material.dart';
import 'package:aurogram/utils/theme/app_theme.dart';

/// Web application root widget
class WebApp extends StatelessWidget {
  const WebApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aurogram Web',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.brown,
        primaryColor: AppTheme.primaryColor,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const ResponsiveLayout(),
    );
  }
}

/// Responsive layout for web application
class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({super.key});

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final isLandscape = orientation == Orientation.landscape;

            return Scaffold(
              appBar: AppBar(
                title: const Text('Aurogram Web'),
              ),
              body: SafeArea(
                child: isLandscape
                    ? _buildLandscapeLayout(context, constraints)
                    : _buildPortraitLayout(context, constraints),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPortraitLayout(
      BuildContext context, BoxConstraints constraints) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Text(
            'Hello, World! Web version is working!',
            style: TextStyle(fontSize: 18),
          ),
          SizedBox(height: 20),
          Text(
            'Rotate device to see landscape layout',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildLandscapeLayout(
      BuildContext context, BoxConstraints constraints) {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Expanded(
            flex: 1,
            child: Center(
              child: Text(
                'Sidebar',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ),
          VerticalDivider(width: 1),
          Expanded(
            flex: 3,
            child: Center(
              child: Text(
                'Main Content Area',
                style: TextStyle(fontSize: 24),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
