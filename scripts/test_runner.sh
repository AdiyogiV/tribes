#!/bin/bash

# Test runner script for the DM functionality
echo "🧪 Running DM Functionality Tests"
echo "=================================="

# Run specific test suites
echo ""
echo "📋 Running Service Tests..."
flutter test test/services/chat/space_chat_service_test.dart --reporter=expanded

echo ""
echo "🖥️  Running Widget Tests..."
flutter test test/pages/tabs/messages_test.dart --reporter=expanded

echo ""
echo "🔗 Running Integration Tests..."
flutter test test/integration/dm_integration_test.dart --reporter=expanded

echo ""
echo "📊 Running All Tests with Coverage..."
flutter test --coverage

echo ""
echo "✅ Test run complete!"
echo ""
echo "📈 To view coverage report:"
echo "   genhtml coverage/lcov.info -o coverage/html"
echo "   open coverage/html/index.html"


