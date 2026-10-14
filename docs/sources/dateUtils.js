import * as System from 'system';
import * as Gettext from 'gettext';
import GLib from 'gi://GLib';
import Gio from 'gi://Gio';
import Shell from 'gi://Shell';

import * as Params from './params.js';

let _desktopSettings = null;
let _localTimeZone = null;

function _convertJSDateToGLibDateTime(date) {
    if (_localTimeZone === null)
        _localTimeZone = GLib.TimeZone.new_local();

    const dt = GLib.DateTime.new(_localTimeZone,
        date.getFullYear(),
        date.getMonth() + 1,
        date.getDate(),
        date.getHours(),
        date.getMinutes(),
        date.getSeconds());

    return dt;
}

export function formatDateWithCFormatString(date, format) {
    const dt = _convertJSDateToGLibDateTime(date);

    return dt?.format(format) ?? '';
}

export function formatTimeSpan(date) {
    if (_localTimeZone === null)
        _localTimeZone = GLib.TimeZone.new_local();

    const now = GLib.DateTime.new_now(_localTimeZone);
    const timespan = now.difference(date);

    const minutesAgo = timespan / GLib.TIME_SPAN_MINUTE;
    const hoursAgo = timespan / GLib.TIME_SPAN_HOUR;
    const daysAgo = timespan / GLib.TIME_SPAN_DAY;
    const weeksAgo = daysAgo / 7;
    const monthsAgo = daysAgo / 30;
    const yearsAgo = weeksAgo / 52;

    if (minutesAgo < 5)
        return _('Just now');
    if (hoursAgo < 1) {
        return Gettext.ngettext(
            '%d minute ago',
            '%d minutes ago',
            minutesAgo
        ).format(minutesAgo);
    }
    if (daysAgo < 1) {
        return Gettext.ngettext(
            '%d hour ago',
            '%d hours ago',
            hoursAgo
        ).format(hoursAgo);
    }
    if (daysAgo < 2)
        return _('Yesterday');
    if (daysAgo < 15) {
        return Gettext.ngettext(
            '%d day ago',
            '%d days ago',
            daysAgo
        ).format(daysAgo);
    }
    if (weeksAgo < 8) {
        return Gettext.ngettext(
            '%d week ago',
            '%d weeks ago',
            weeksAgo
        ).format(weeksAgo);
    }
    if (yearsAgo < 1) {
        return Gettext.ngettext(
            '%d month ago',
            '%d months ago',
            monthsAgo
        ).format(monthsAgo);
    }
    return Gettext.ngettext(
        '%d year ago',
        '%d years ago',
        yearsAgo
    ).format(yearsAgo);
}

export function formatTime(time, params) {
    let date;
    if (time instanceof Date)
        date = _convertJSDateToGLibDateTime(time);
    else
        date = time;

    if (!date)
        return '';

    const now = GLib.DateTime.new_now(_localTimeZone);
    const daysAgo = now.difference(date) / (24 * 60 * 60 * 1000 * 1000);

    let format;

    if (_desktopSettings == null)
        _desktopSettings = new Gio.Settings({schema_id: 'org.gnome.desktop.interface'});
    const clockFormat = _desktopSettings.get_string('clock-format');

    params = Params.parse(params, {
        timeOnly: false,
        ampm: true,
    });

    if (clockFormat === '24h') {
        if (daysAgo < 1 || params.timeOnly)
            format = N_('%H:%M');
        else if (daysAgo < 2)
            format = N_('Yesterday, %H:%M');
        else if (daysAgo < 7)
            format = N_('%A, %H:%M');
        else if (date.get_year() === now.get_year())
            format = N_('%B %-d, %H:%M');
        else
            format = N_('%B %-d %Y, %H:%M');
    } else {
        if (daysAgo < 1 || params.timeOnly)
            format = N_('%l:%M %p');
        else if (daysAgo < 2)
            format = N_('Yesterday, %l:%M %p');
        else if (daysAgo < 7)
            format = N_('%A, %l:%M %p');
        else if (date.get_year() === now.get_year())
            format = N_('%B %-d, %l:%M %p');
        else
            format = N_('%B %-d %Y, %l:%M %p');
    }

    if (!params.ampm)
        format = format.replace(/\s*%p/g, '');

    return date.format(Shell.util_translate_time_string(format));
}

export function clearCachedLocalTimeZone() {
    System.clearDateCaches();

    _localTimeZone = GLib.TimeZone.new_local();
}
