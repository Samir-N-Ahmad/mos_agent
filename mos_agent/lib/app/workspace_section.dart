import 'package:flutter/material.dart';

enum WorkspaceSection {
  profile(
    'Profile',
    Icons.person_outline,
    Icons.person,
    'Your workspace profile',
    'Account information will appear here when sign-in is connected.',
  ),
  settings(
    'Settings',
    Icons.settings_outlined,
    Icons.settings,
    'Make this workspace yours',
    'Application preferences and integration settings will appear here.',
  ),
  chats(
    'Chats',
    Icons.chat_bubble_outline,
    Icons.chat_bubble,
    'A place for every conversation',
    'Your help-desk conversations will appear here when a ticket system is connected.',
  ),
  media(
    'Media',
    Icons.perm_media_outlined,
    Icons.perm_media,
    'Everything you share, together',
    'Ticket attachments and shared files will appear here.',
  );

  const WorkspaceSection(
    this.title,
    this.icon,
    this.selectedIcon,
    this.emptyTitle,
    this.description,
  );

  final String title;
  final IconData icon;
  final IconData selectedIcon;
  final String emptyTitle;
  final String description;
}
