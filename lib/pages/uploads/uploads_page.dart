import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:aurogram/services/media/media_compression_service.dart';
import 'package:aurogram/widgets/ui/upload_progress_tracker.dart';
import 'package:aurogram/widgets/ui/skeleton_widgets.dart';
import 'package:aurogram/utils/theme/app_dimensions.dart';

class UploadsPage extends StatefulWidget {
  final VoidCallback? onAllComplete;

  const UploadsPage({super.key, this.onAllComplete});

  @override
  UploadsPageState createState() => UploadsPageState();
}

class UploadsPageState extends State<UploadsPage> {
  final MediaCompressionService _compressionService = MediaCompressionService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CupertinoTheme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: CupertinoTheme.of(context).barBackgroundColor,
        elevation: 0,
        title: Text(
          'Uploads',
          style: TextStyle(
            color: CupertinoTheme.of(context).textTheme.textStyle.color,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: CupertinoTheme.of(context).primaryColor,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Instructions or empty state
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _compressionService.getUploadProgress(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return ListView.builder(
                    padding: const EdgeInsets.all(AppDimensions.paddingLg),
                    itemCount: 3,
                    itemBuilder: (_, __) => const Padding(
                      padding: EdgeInsets.only(bottom: AppDimensions.paddingMd),
                      child: SkeletonListItem(height: 80),
                    ),
                  );
                }

                final uploads = snapshot.data ?? [];

                if (uploads.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.cloud_upload_outlined,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        SizedBox(height: AppDimensions.spacingLg),
                        Text(
                          'No uploads in progress',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: AppDimensions.spacingSm),
                        Text(
                          'Your video uploads will appear here',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Upload stats summary
                final active = uploads
                    .where((item) =>
                        item['status'] != 'completed' &&
                        item['status'] != 'failed' &&
                        item['status'] != 'cancelled')
                    .length;

                final completed = uploads
                    .where((item) => item['status'] == 'completed')
                    .length;

                final failed = uploads
                    .where((item) =>
                        item['status'] == 'failed' ||
                        item['status'] == 'cancelled')
                    .length;

                return Column(
                  children: [
                    // Upload stats with improved styling
                    Container(
                      padding:
                          EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                      margin: EdgeInsets.fromLTRB(16, 16, 16, 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem(
                              active, 'Active', Colors.blue, Icons.sync),
                          _buildDivider(),
                          _buildStatItem(completed, 'Completed', Colors.green,
                              Icons.check_circle),
                          _buildDivider(),
                          _buildStatItem(failed, 'Failed', Colors.red,
                              Icons.error_outline),
                        ],
                      ),
                    ),

                    // Progress tracker takes the rest of the space
                    Expanded(
                      child: UploadProgressTracker(
                        compressionService: _compressionService,
                        fullScreenMode: true,
                        context: context,
                        onAllComplete: widget.onAllComplete,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(int count, String label, Color color, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(
            icon,
            size: 24,
            color: color,
          ),
          SizedBox(height: AppDimensions.spacingSm),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: AppDimensions.spacingXs),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 40,
      width: 1,
      color: Colors.grey[200],
    );
  }
}
