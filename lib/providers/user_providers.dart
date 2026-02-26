import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myna/providers/home_providers.dart';
import 'package:myna/providers/support_providers.dart';
import 'package:myna/providers/feedback_providers.dart';
import 'package:myna/providers/bookmark_provider.dart';
import 'package:myna/providers/author_follow_provider.dart';
import 'package:myna/services/wishlist_service.dart';
import 'package:myna/services/auth_service.dart';
import 'package:myna/screens/listener/profile_screen.dart';
import 'package:myna/screens/listener/library_screen.dart';
import 'package:myna/screens/narrator/narrator_profile_screen.dart';
import 'package:myna/screens/narrator/narrator_dashboard_screen.dart';
import 'package:myna/utils/app_logger.dart';

/// Invalidates all user-specific providers when auth state changes.
/// This ensures fresh data is fetched for the new user.
void invalidateUserProviders(WidgetRef ref) {
  AppLogger.i('Invalidating all user-specific providers');

  // Profile providers
  ref.invalidate(profileDataProvider);
  ref.invalidate(profileProvider);
  ref.invalidate(narratorProfileProvider);
  ref.invalidate(narratorStatsProvider);
  ref.invalidate(narratorDashboardStatsProvider);

  // Home/listening providers
  ref.invalidate(continueListeningProvider);
  ref.invalidate(homeRecentlyPlayedProvider);
  ref.invalidate(listeningStatsProvider);

  // Library/ownership providers - invalidate all content types and legacy providers
  ref.invalidate(ownedItemsWithProgressProvider(ContentType.books));
  ref.invalidate(ownedItemsWithProgressProvider(ContentType.music));
  ref.invalidate(ownedItemsWithProgressProvider(ContentType.podcasts));
  ref.invalidate(ownedBooksWithProgressProvider);  // Legacy
  ref.invalidate(wishlistItemsProvider(ContentType.books));
  ref.invalidate(wishlistItemsProvider(ContentType.music));
  ref.invalidate(wishlistItemsProvider(ContentType.podcasts));
  ref.invalidate(wishlistBooksProvider);  // Legacy
  ref.invalidate(wishlistProvider);

  // Support providers
  ref.invalidate(userTicketsProvider);
  ref.invalidate(userOpenTicketsCountProvider);

  // Feedback providers
  ref.invalidate(narratorFeedbackProvider);
  ref.invalidate(unreadFeedbackCountProvider);

  // Bookmark provider - reset state
  ref.invalidate(bookmarkProvider);

  // Author follow provider - reload from Supabase for new user
  ref.invalidate(authorFollowProvider);

  AppLogger.i('User providers invalidated');
}

/// Same as invalidateUserProviders but uses ProviderContainer directly
/// (useful when you don't have a WidgetRef)
void invalidateUserProvidersWithContainer(ProviderContainer container) {
  AppLogger.i('Invalidating all user-specific providers (container)');

  // Profile providers
  container.invalidate(profileDataProvider);
  container.invalidate(profileProvider);
  container.invalidate(narratorProfileProvider);
  container.invalidate(narratorStatsProvider);
  container.invalidate(narratorDashboardStatsProvider);

  // Home/listening providers
  container.invalidate(continueListeningProvider);
  container.invalidate(homeRecentlyPlayedProvider);
  container.invalidate(listeningStatsProvider);

  // Library/ownership providers - invalidate all content types and legacy providers
  container.invalidate(ownedItemsWithProgressProvider(ContentType.books));
  container.invalidate(ownedItemsWithProgressProvider(ContentType.music));
  container.invalidate(ownedItemsWithProgressProvider(ContentType.podcasts));
  container.invalidate(ownedBooksWithProgressProvider);  // Legacy
  container.invalidate(wishlistItemsProvider(ContentType.books));
  container.invalidate(wishlistItemsProvider(ContentType.music));
  container.invalidate(wishlistItemsProvider(ContentType.podcasts));
  container.invalidate(wishlistBooksProvider);  // Legacy
  container.invalidate(wishlistProvider);

  // Support providers
  container.invalidate(userTicketsProvider);
  container.invalidate(userOpenTicketsCountProvider);

  // Feedback providers
  container.invalidate(narratorFeedbackProvider);
  container.invalidate(unreadFeedbackCountProvider);

  // Bookmark provider - reset state
  container.invalidate(bookmarkProvider);

  // Author follow provider - reload from Supabase for new user
  container.invalidate(authorFollowProvider);

  AppLogger.i('User providers invalidated (container)');
}
