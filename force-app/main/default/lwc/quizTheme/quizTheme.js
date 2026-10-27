import { LightningElement, api } from 'lwc';

/** Shared layout: design tokens, background sky, header, footer. Children inherit the tokens through the slot. */
export default class QuizTheme extends LightningElement {
    @api me;
    @api page;

    get isLoggedIn() {
        return !!this.me;
    }
    get initial() {
        return (this.me && this.me.displayName ? this.me.displayName : '?').charAt(0).toUpperCase();
    }
    get homeCls() {
        return 'link' + (this.page === 'home' ? ' current' : '');
    }
    get playCls() {
        return 'link' + (this.page === 'play' || this.page === 'room' ? ' current' : '');
    }
    get boardCls() {
        return 'link' + (this.page === 'profile' && !this.isOwnProfile ? ' current' : '');
    }
    get isOwnProfile() {
        return false;
    }

    go(event) {
        const page = event.currentTarget.dataset.page;
        const state = page === 'profile' && this.me ? { u: this.me.username } : undefined;
        this.dispatchEvent(new CustomEvent('navigate', { detail: { page, state } }));
    }
    goBoard() {
        this.dispatchEvent(new CustomEvent('navigate', { detail: { page: 'profile', state: { tab: 'leaders' } } }));
    }
    logout() {
        this.dispatchEvent(new CustomEvent('logout'));
    }
}