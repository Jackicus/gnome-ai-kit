import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';

import {@CLASS@App} from './lib/app.js';

export default class @CLASS@Extension extends Extension {
    enable() {
        this._app = new @CLASS@App(this);
        this._app.enable();
    }

    disable() {
        this._app.disable();
        this._app = null;
    }
}
