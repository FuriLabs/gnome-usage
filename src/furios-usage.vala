/* furios-usage.vala
 *
 * Copyright (C) 2025 Bardia Moshiri
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
 * Authors: Bardia Moshiri <bardia@furilabs.com>
 */

using GTop;

[DBus (name = "io.furios.Andromeda.SessionManager")]
public interface Usage.AndromedaSessionManager : Object {
    public abstract string NameToPackageName (string app_name) throws IOError, DBusError;
}

[DBus (name = "io.furios.Andromeda.ContainerManager")]
public interface Usage.AndromedaContainerManager : Object {
    public abstract void KillApp (string package_name) throws IOError, DBusError;
}

public class Usage.FuriOS : Object {
    private static AndromedaSessionManager? session_manager;
    private static AndromedaContainerManager? container_manager;

    public static void get_root_filesystem_usage(out uint64 total_size, out uint64 used_size, out uint64 free_size) {
        FsUsage root_fs;
        GTop.get_fsusage (out root_fs, "/");

        total_size = root_fs.blocks * root_fs.block_size;
        free_size = root_fs.bfree * root_fs.block_size;
        used_size = total_size - free_size;
    }

    private static bool init_dbus_connections () {
        try {
            session_manager = Bus.get_proxy_sync (BusType.SESSION,
                                                  "io.furios.Andromeda.Session",
                                                  "/SessionManager");
            container_manager = Bus.get_proxy_sync (BusType.SYSTEM,
                                                   "io.furios.Andromeda.Container",
                                                   "/ContainerManager");
            return true;
        } catch (IOError e) {
            warning ("Failed to connect to Andromeda DBus services: %s", e.message);
            return false;
        }
    }

    public static bool kill_andromeda_app (string app_name) {
        if (session_manager == null || container_manager == null) {
            if (!init_dbus_connections ())
                return false;
        }

        try {
            debug ("Attempting to kill Andromeda app: %s", app_name);
            string package_name = session_manager.NameToPackageName (app_name);

            if (package_name == "") {
                warning ("Could not resolve Andromeda app '%s' to a package name", app_name);
                return false;
            }

            debug ("Resolved app '%s' to package name '%s'", app_name, package_name);
            container_manager.KillApp (package_name);
            debug ("Successfully sent kill command for Andromeda app '%s' (package: %s)", app_name, package_name);

            return true;
        } catch (IOError e) {
            warning ("IO error when killing Andromeda app '%s': %s", app_name, e.message);
            return false;
        } catch (DBusError e) {
            warning ("DBus error when killing Andromeda app '%s': %s", app_name, e.message);
            return false;
        }
    }
}
