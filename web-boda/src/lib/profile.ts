import type {Profile} from './types'
export type EditableProfile=Pick<Profile,'full_name'|'alias'|'phone'|'email_updates'|'in_app_updates'|'leaderboard_visible'>
// Never send the profile's id, consent timestamp or creation timestamp in an UPDATE.
export function editableProfile(profile:EditableProfile):EditableProfile{
 return {full_name:profile.full_name.trim(),alias:profile.alias.trim(),phone:profile.phone.trim(),email_updates:profile.email_updates,in_app_updates:profile.in_app_updates,leaderboard_visible:profile.leaderboard_visible}
}
