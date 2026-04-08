/// Re-export barrel for backward compatibility.
///
/// All types have been moved to `lib/providers/ai_chat/` as focused modules.
/// This file preserves the existing import path so no consumer changes are needed.
library;

export 'ai_chat/ai_chat_models.dart';
export 'ai_chat/ai_chat_provider.dart';
