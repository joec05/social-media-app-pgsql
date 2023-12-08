delete from basic_data.user_profile;
delete from blocked_users.block_history;
delete from follow_requests_users.follow_request_history;
delete from follow_users.follow_history;
delete from muted_users.mute_history;
delete from sensitive_data.user_password;

delete from bookmarks_list.posts;
delete from bookmarks_list.comments;
delete from comments_list.comments_data;
delete from likes_list.posts;
delete from likes_list.comments;
delete from posts_list.posts_data;

delete from group_messages.messages_history;
delete from group_profile.group_info;
delete from private_messages.messages_history;
delete from users_chats.chats_history;

delete from notifications_data.notifications_history;

delete from hashtags.hashtags_list;