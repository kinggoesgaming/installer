// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2018 elementary LLC. (https://elementary.io)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authored by: Cassidy James Blaede <c@ssidyjam.es>
 *
 */
public class DecryptDialog: Gtk.Dialog {
    private Gtk.ListBox partition_list;
    private unowned string selected_device;

    public DecryptDialog () {
        Object (
            title: "Unlock",
            deletable: false,
            resizable: false,
            skip_taskbar_hint: true,
            skip_pager_hint: true
        );
    }

    construct {
        var image = new Gtk.Image.from_icon_name ("drive-harddisk", Gtk.IconSize.DIALOG);
        image.valign = Gtk.Align.START;

        var overlay_image = new Gtk.Image.from_icon_name ("dialog-password", Gtk.IconSize.DND);
        overlay_image.halign = Gtk.Align.END;
        overlay_image.valign = Gtk.Align.END;

        var overlay = new Gtk.Overlay ();
        overlay.halign = Gtk.Align.CENTER;
        overlay.valign = Gtk.Align.END;
        overlay.width_request = 60;
        overlay.add (image);
        overlay.add_overlay (overlay_image);

        var primary_label = new Gtk.Label (_("Select a Partition to Unlock"));
        primary_label.max_width_chars = 50;
        primary_label.selectable = true;
        primary_label.wrap = true;
        primary_label.xalign = 0;
        primary_label.get_style_context ().add_class (Granite.STYLE_CLASS_PRIMARY_LABEL);

        var secondary_label = new Gtk.Label (_("There are multiple encrypted partitions. Choose one to unlock with its password."));
        secondary_label.max_width_chars = 50;
        secondary_label.selectable = true;
        secondary_label.wrap = true;
        secondary_label.xalign = 0;

        partition_list = new Gtk.ListBox ();
        partition_list.expand = true;
        partition_list.margin_top = 12;

        var pass_label = new Gtk.Label (_("Password:"));
        pass_label.halign = Gtk.Align.END;

        pass_entry = new Gtk.Entry ();
        pass_entry.hexpand = true;
        pass_entry.input_purpose = Gtk.InputPurpose.PASSWORD;
        pass_entry.visibility = false;

        var name_label = new Gtk.Label (_("Device name:"));
        name_label.halign = Gtk.Align.END;

        name_entry = new Gtk.Entry ();
        name_entry.hexpand = true;
        name_entry.text = "data"; // Set a sane default

        var entry_grid = new Gtk.Grid ();
        entry_grid.column_spacing = 12;
        entry_grid.valign = Gtk.Align.CENTER;
        entry_grid.vexpand = true;
        entry_grid.row_spacing = 6;
        entry_grid.margin_top = 12;
        entry_grid.attach (pass_label, 0, 0);
        entry_grid.attach (pass_entry, 1, 0);
        entry_grid.attach (name_label, 0, 1);
        entry_grid.attach (name_entry, 1, 1);

        var stack = new Gtk.Stack ();
        stack.height_request = 128;
        stack.transition_type = Gtk.StackTransitionType.SLIDE_LEFT_RIGHT;
        stack.add (partition_list);
        stack.add (entry_grid);

        var grid = new Gtk.Grid ();
        grid.column_spacing = 12;
        grid.margin_start = grid.margin_end = 12;
        grid.attach (overlay,         0, 0, 1, 2);
        grid.attach (primary_label,   1, 0);
        grid.attach (secondary_label, 1, 1);
        grid.attach (stack,           1, 2);
        grid.show_all ();
        get_content_area ().add (grid);

        var cancel_button = (Gtk.Button) add_button (_("Cancel"), Gtk.ResponseType.CANCEL);

        var select_button = (Gtk.Button) add_button (_("Select"), Gtk.ResponseType.NONE);
        select_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);

        var back_button = (Gtk.Button) add_button (_("Back"), Gtk.ResponseType.NONE);
        back_button.hide ();

        var unlock_button = (Gtk.Button) add_button (_("Unlock"), Gtk.ResponseType.NONE);
        unlock_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);
        unlock_button.hide ();
        unlock_button.clicked.connect (() => {
            string pv = name_entry.get_text ();
            string pass = pass_entry.get_text ();

            try {
                InstallOptions.get_default ().decrypt (selected_device, pv, pass);
            } catch (Error e) {
                stderr.printf ("failed to decrypt: %s\n", e.message);
                return;
            }
        });

        var action_area = get_action_area ();
        action_area.margin = 6;
        action_area.margin_top = 12;

        set_keep_above (true);

        partition_list.row_selected.connect ((row) => {
            if (row == null) {
                return;
            }

            unowned Gtk.Grid inner_grid = (Gtk.Grid) row.get_children ().nth_data (0);
            foreach (unowned Gtk.Widget widget in inner_grid.get_children ()) {
                if (widget is Gtk.Label) {
                    this.selected_device = ((Gtk.Label) widget).get_label ();
                    stderr.printf ("selected device: %s\n", selected_device);
                    break;
                }
            }
        });

        cancel_button.clicked.connect (() => destroy ());

        select_button.clicked.connect (() => {
            stack.visible_child = entry_grid;
            cancel_button.hide ();
            select_button.hide ();
            back_button.show ();
            unlock_button.show ();
        });

        back_button.clicked.connect (() => {
            stack.visible_child = partition_list;
            back_button.hide ();
            unlock_button.hide ();
            cancel_button.show ();
            select_button.show ();
        });

        unlock_button.clicked.connect (() => destroy ());
    }

    public void update_list () {
        stderr.printf("updating partition list\n");
        this.partition_list.get_children ().foreach ((child) => child.destroy ());
        var options = InstallOptions.get_default ();

        unowned Distinst.Disks disks = options.borrow_disks ();
        foreach (unowned Distinst.Partition partition in disks.get_encrypted_partitions ()) {
            string path = Utils.string_from_utf8 (partition.get_device_path ());

            var lock_icon_name = options.is_unlocked (path) ? "emblem-unlocked" : "dialog-password";
            var lock_icon = new Gtk.Image.from_icon_name (lock_icon_name, Gtk.IconSize.MENU);
            lock_icon.margin = 6;

            var label = new Gtk.Label (path);
            label.hexpand = true;
            label.margin = 6;
            label.xalign = 0;
            label.get_style_context ().add_class (Granite.STYLE_CLASS_H3_LABEL);

            var grid = new Gtk.Grid ();
            grid.attach (label, 0, 0);
            grid.attach (lock_icon, 1, 0);

            var row = new Gtk.ListBoxRow ();
            row.add (grid);
            row.show_all ();

            this.partition_list.add (row);
        }
    }
}
