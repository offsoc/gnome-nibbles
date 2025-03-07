/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*-
 * Gnome Nibbles: Gnome Worm Game
 * Copyright (C) 2015 Iulian-Gabriel Radu <iulian.radu67@gmail.com>
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
 */

private class WormActor : Clutter.Actor
{
    public override void show ()
    {
        base.show ();

        set_opacity (0);
        set_scale (3.0, 3.0);

        save_easing_state ();
        set_easing_mode (Clutter.AnimationMode.EASE_OUT_CIRC);
        set_easing_duration (NibblesGame.GAMEDELAY * 26);
        set_scale (1.0, 1.0);
        set_pivot_point (0.5f, 0.5f);
        set_opacity (0xff);
        restore_easing_state ();
    }

    public override void hide ()
    {
        save_easing_state ();
        set_easing_mode (Clutter.AnimationMode.EASE_IN_QUAD);
        set_easing_duration (NibblesGame.GAMEDELAY * 15);
        set_scale (0.4f, 0.4f);
        set_opacity (0);
        restore_easing_state ();
    }
}

private class BonusTexture : GtkClutter.Texture
{
    public const float SIZE_MULTIPLIER = 2;

    public override void show ()
    {
        base.show ();

        set_opacity (0);
        set_scale (3.0, 3.0);

        save_easing_state ();
        set_easing_mode (Clutter.AnimationMode.EASE_OUT_BOUNCE);
        set_easing_duration (NibblesGame.GAMEDELAY * 20);
        set_scale (1.0, 1.0);
        set_pivot_point (0.5f, 0.5f);
        set_opacity (0xff);
        restore_easing_state ();
    }

    public new void set_size (float width, float height)
    {
        base.set_size (SIZE_MULTIPLIER * width, SIZE_MULTIPLIER * height);
    }
}

private class WarpTexture: GtkClutter.Texture
{
    public const float SIZE_MULTIPLIER = 2;

    public override void show ()
    {
        base.show ();

        set_opacity (0);
        set_scale (3.0, 3.0);

        save_easing_state ();
        set_easing_mode (Clutter.AnimationMode.EASE_OUT_CIRC);
        set_easing_duration (NibblesGame.GAMEDELAY * 15);
        set_scale (1.0, 1.0);
        set_pivot_point (0.5f, 0.5f);
        set_opacity (0xff);
        restore_easing_state ();
    }

    public override void hide ()
    {
        save_easing_state ();
        set_easing_mode (Clutter.AnimationMode.EASE_IN_QUAD);
        set_easing_duration (NibblesGame.GAMEDELAY * 15);
        set_scale (0.4f, 0.4f);
        set_pivot_point (0.5f, 0.5f);
        set_opacity (0);
        restore_easing_state ();
    }

    public new void set_size (float width, float height)
    {
        base.set_size (SIZE_MULTIPLIER * width, SIZE_MULTIPLIER * height);
    }
}

public class NibblesView : GtkClutter.Embed
{
    /* Sound */
    public bool is_muted;

    /* Pixmaps */
    private Gdk.Pixbuf wall_pixmaps[11];
    private Gdk.Pixbuf worm_pixmaps[6];
    private Gdk.Pixbuf boni_pixmaps[9];

    /* Actors */
    private Clutter.Stage stage;
    private Clutter.Actor level;
    public Clutter.Actor name_labels { get; private set; }

    private Gee.HashMap<Worm, WormActor> worm_actors;
    private Gee.HashMap<Bonus, BonusTexture> bonus_actors;
    private Gee.HashMap<Warp, WarpTexture> warp_actors;

    /* Game being played */
    private NibblesGame _game;
    public NibblesGame game
    {
        get { return _game; }
        set
        {
            if (_game != null)
                SignalHandler.disconnect_matched (_game, SignalMatchType.DATA, 0, 0, null, null, this);

            _game = value;
            _game.boni.bonus_added.connect (bonus_added_cb);
            _game.boni.bonus_removed.connect (bonus_removed_cb);

            _game.bonus_applied.connect (bonus_applied_cb);

            _game.warp_manager.warp_added.connect (warp_added_cb);

            _game.animate_end_game.connect (animate_end_game_cb);
        }
    }

    /* Colors */
    public const int NUM_COLORS = 6;
    public static string[] color_lookup =
    {
      N_("red"),
      N_("green"),
      N_("blue"),
      N_("yellow"),
      N_("cyan"),
      N_("purple")
    };

    public NibblesView (NibblesGame game)
    {
        this.game = game;

        stage = (Clutter.Stage) get_stage ();
        Clutter.Color stage_color = { 0x00, 0x00, 0x00, 0xff };
        stage.set_background_color (stage_color);

        set_size_request (NibblesGame.MINIMUM_TILE_SIZE * NibblesGame.WIDTH,
                          NibblesGame.MINIMUM_TILE_SIZE * NibblesGame.HEIGHT);

        worm_actors = new Gee.HashMap<Worm, WormActor> ();
        bonus_actors = new Gee.HashMap<Bonus, BonusTexture> ();
        warp_actors = new Gee.HashMap<Warp, WarpTexture> ();

        load_pixmap ();
    }

    /*\
    * * Level creationg and loading
    \*/

    public void new_level (int level)
    {
        string level_name;
        string filename;
        string tmpboard;
        int count = 0;

        level_name = "level%03d.gnl".printf (level);
        filename = Path.build_filename (PKGDATADIR, "levels", level_name, null);

        FileStream file;
        if ((file = FileStream.open (filename, "r")) == null)
            error ("Nibbles couldn't find pixmap file: %s", filename);

        foreach (var actor in worm_actors.values)
            actor.destroy ();
        worm_actors.clear ();

        foreach (var actor in bonus_actors.values)
            actor.destroy ();
        bonus_actors.clear ();

        foreach (var actor in warp_actors.values)
            actor.destroy ();
        warp_actors.clear ();

        game.boni.reset (game.numworms);
        game.warp_manager.warps.clear ();

        for (int i = 0; i < NibblesGame.HEIGHT; i++)
        {
            if ((tmpboard = file.read_line ()) == null)
                error ("Level file appears to be damaged: %s", filename);

            for (int j = 0; j < NibblesGame.WIDTH; j++)
            {
                game.board[j, i] = tmpboard.get(j);
                switch (game.board[j, i])
                {
                    case 'm':
                        game.board[j, i] = NibblesGame.EMPTYCHAR;
                        if (count < game.numworms)
                        {
                            game.worms[count].set_start (j, i, WormDirection.UP);

                            var actors = new WormActor ();
                            stage.add_child (actors);
                            worm_actors.set (game.worms[count], actors);
                            count++;
                        }
                        break;
                    case 'n':
                        game.board[j, i] = NibblesGame.EMPTYCHAR;
                        if (count < game.numworms)
                        {
                            game.worms[count].set_start (j, i, WormDirection.LEFT);

                            var actors = new WormActor ();
                            stage.add_child (actors);
                            worm_actors.set (game.worms[count], actors);
                            count++;
                        }
                        break;
                    case 'o':
                        game.board[j, i] = NibblesGame.EMPTYCHAR;
                        if (count < game.numworms)
                        {
                            game.worms[count].set_start (j, i, WormDirection.DOWN);

                            var actors = new WormActor ();
                            stage.add_child (actors);
                            worm_actors.set (game.worms[count], actors);
                            count++;
                        }
                        break;
                    case 'p':
                        game.board[j, i] = NibblesGame.EMPTYCHAR;
                        if (count < game.numworms)
                        {
                            game.worms[count].set_start (j, i, WormDirection.RIGHT);

                            var actors = new WormActor ();
                            stage.add_child (actors);
                            worm_actors.set (game.worms[count], actors);
                            count++;
                        }
                        break;
                    default:
                        break;
                }
            }
        }

        load_level ();
    }

    private void load_level ()
    {
        int x_pos, y_pos;
        GtkClutter.Texture tmp = null;
        bool is_wall = true;

        if (level != null)
        {
            level.remove_all_children ();
            stage.remove_child (level);
        }

        level = new Clutter.Actor ();

        /* Load wall_pixmaps onto the surface */
        for (int i = 0; i < NibblesGame.HEIGHT; i++)
        {
            y_pos = i * game.tile_size;
            for (int j = 0; j < NibblesGame.WIDTH; j++)
            {
                is_wall = true;
                try
                {
                    switch (game.board[j, i])
                    {
                        case 'a': // empty space
                            is_wall = false;
                            break;
                        case 'b': // straight up
                            tmp = new GtkClutter.Texture ();
                            tmp.set_from_pixbuf (wall_pixmaps[0]);
                            break;
                        case 'c': // straight side
                            tmp = new GtkClutter.Texture ();
                            tmp.set_from_pixbuf (wall_pixmaps[1]);
                            break;
                        case 'd': // corner bottom left
                            tmp = new GtkClutter.Texture ();
                            tmp.set_from_pixbuf (wall_pixmaps[2]);
                            break;
                        case 'e': // corner bottom right
                            tmp = new GtkClutter.Texture ();
                            tmp.set_from_pixbuf (wall_pixmaps[3]);
                            break;
                        case 'f': // corner up left
                            tmp = new GtkClutter.Texture ();
                            tmp.set_from_pixbuf (wall_pixmaps[4]);
                            break;
                        case 'g': // corner up right
                            tmp = new GtkClutter.Texture ();
                            tmp.set_from_pixbuf (wall_pixmaps[5]);
                            break;
                        case 'h': // tee up
                            tmp = new GtkClutter.Texture ();
                            tmp.set_from_pixbuf (wall_pixmaps[6]);
                            break;
                        case 'i': // tee right
                            tmp = new GtkClutter.Texture ();
                            tmp.set_from_pixbuf (wall_pixmaps[7]);
                            break;
                        case 'j': // tee left
                            tmp = new GtkClutter.Texture ();
                            tmp.set_from_pixbuf (wall_pixmaps[8]);
                            break;
                        case 'k': // tee down
                            tmp = new GtkClutter.Texture ();
                            tmp.set_from_pixbuf (wall_pixmaps[9]);
                            break;
                        case 'l': // tee cross
                            tmp = new GtkClutter.Texture ();
                            tmp.set_from_pixbuf (wall_pixmaps[10]);
                            break;
                        case 'Q':
                        case 'R':
                        case 'S':
                        case 'T':
                        case 'U':
                        case 'V':
                        case 'W':
                        case 'X':
                        case 'Y':
                        case 'Z':
                            is_wall = false;
                            game.warp_manager.add_warp (game.board, j - 1, i - 1, -(game.board[j, i]), 0);
                            break;
                        case 'r':
                        case 's':
                        case 't':
                        case 'u':
                        case 'v':
                        case 'w':
                        case 'x':
                        case 'y':
                        case 'z':
                            is_wall = false;
                            game.warp_manager.add_warp (game.board, -(game.board[j, i] - 'a' + 'A'), 0, j, i);
                            game.board[j, i] = NibblesGame.EMPTYCHAR;
                            break;
                        default:
                            is_wall = false;
                            break;
                    }
                }
                catch (Error e)
                {
                    error ("Error loading level: %s", e.message);
                }

                if (is_wall)
                {
                    x_pos = j * game.tile_size;

                    tmp.set_size (game.tile_size, game.tile_size);
                    tmp.set_position (x_pos, y_pos);
                    level.add_child (tmp);
                }
            }
        }
        stage.add_child (level);

        level.set_opacity (0);
        level.set_scale (0.2, 0.2);

        level.save_easing_state ();
        level.set_easing_mode (Clutter.AnimationMode.EASE_OUT_BOUNCE);
        level.set_easing_duration (NibblesGame.GAMEDELAY * NibblesGame.GAMEDELAY);
        level.set_scale (1.0, 1.0);
        level.set_pivot_point (0.5f, 0.5f);
        level.set_opacity (0xff);
        level.restore_easing_state ();
    }

    /*\
    * * Pixmaps loading
    \*/

    public Gdk.Pixbuf load_pixmap_file (string pixmap, int xsize, int ysize)
    {
        var filename = Path.build_filename (PKGDATADIR, "pixmaps", pixmap, null);
        if (filename == null)
            error ("Nibbles couldn't find pixmap file: %s", filename);

        Gdk.Pixbuf image = null;
        try
        {
            image = new Gdk.Pixbuf.from_file_at_scale (filename, xsize, ysize, true);
        }
        catch (Error e)
        {
            warning ("Failed to load pixmap file: %s", e.message);
        }

        return image;
    }

    private void load_pixmap ()
    {
        string[] bonus_files =
        {
            "bonus1.svg",
            "bonus2.svg",
            "bonus3.svg",
            "life.svg",
            "diamond.svg",
            "questionmark.svg"
        };

        string[] small_files =
        {
            "wall-straight-up.svg",
            "wall-straight-side.svg",
            "wall-corner-bottom-left.svg",
            "wall-corner-bottom-right.svg",
            "wall-corner-top-left.svg",
            "wall-corner-top-right.svg",
            "wall-tee-up.svg",
            "wall-tee-right.svg",
            "wall-tee-left.svg",
            "wall-tee-down.svg",
            "wall-cross.svg"
        };

        string[] worm_files =
        {
            "snake-red.svg",
            "snake-green.svg",
            "snake-blue.svg",
            "snake-yellow.svg",
            "snake-cyan.svg",
            "snake-magenta.svg"
        };

        for (int i = 0; i < bonus_files.length; i++)
        {
            boni_pixmaps[i] = load_pixmap_file (bonus_files[i],
                                                2 * game.tile_size, 2 * game.tile_size);
        }

        for (int i = 0; i < small_files.length; i++)
        {
            wall_pixmaps[i] = load_pixmap_file (small_files[i],
                                                2 * game.tile_size, 2 * game.tile_size);
        }

        for (int i = 0; i < worm_files.length; i++)
        {
            worm_pixmaps[i] = load_pixmap_file (worm_files[i],
                                                game.tile_size, game.tile_size);
        }
    }

    public void connect_worm_signals ()
    {
        foreach (var worm in game.worms)
        {
            worm.added.connect (worm_added_cb);
            worm.finish_added.connect (worm_finish_added_cb);
            worm.moved.connect (worm_moved_cb);
            worm.rescaled.connect (worm_rescaled_cb);
            worm.died.connect (worm_died_cb);
            worm.tail_reduced.connect (worm_tail_reduced_cb);
            worm.reversed.connect (worm_reversed_cb);
            worm.notify["is-materialized"].connect (() => {
                uint8 opacity;
                opacity = worm.is_materialized ? 0xff : 0x50;

                var actors = worm_actors.get (worm);

                actors.save_easing_state ();
                actors.set_easing_duration (NibblesGame.GAMEDELAY * 10);
                actors.set_opacity (opacity);
                actors.restore_easing_state ();
            });
        }
    }

    public void board_rescale (int tile_size)
    {
        int board_width, board_height;
        float x_pos, y_pos;

        if (level == null)
            return;

        board_width = NibblesGame.WIDTH * tile_size;
        board_height = NibblesGame.HEIGHT * tile_size;

        foreach (var actor in level.get_children ())
        {
            actor.get_position (out x_pos, out y_pos);
            actor.set_position ((x_pos / game.tile_size) * tile_size,
                                (y_pos / game.tile_size) * tile_size);
            actor.set_size (tile_size, tile_size);
        }

        if (!name_labels.visible)
            return;

        foreach (var worm in game.worms)
        {
            var actor = name_labels.get_child_at_index (worm.id);

            var middle = worm.length / 2;
            if (worm.direction == WormDirection.UP || worm.direction == WormDirection.DOWN)
            {
                actor.set_x (worm.list[middle].x * tile_size - actor.width / 2 + tile_size / 2);
                actor.set_y (worm.list[middle].y * tile_size - 5 * tile_size);
            }
            else if (worm.direction == WormDirection.LEFT || worm.direction == WormDirection.RIGHT)
            {
                actor.set_x (worm.list[middle].x * tile_size - actor.width / 2 + tile_size / 2);
                actor.set_y (worm.head.y * tile_size - 3 * tile_size);
            }
        }
    }

    private void animate_end_game_cb ()
    {
        foreach (var worm in game.worms)
            worm_actors.get (worm).hide ();

        foreach (var warp in game.warp_manager.warps)
            warp_actors.get (warp).hide ();

        level.save_easing_state ();
        level.set_easing_mode (Clutter.AnimationMode.EASE_IN_QUAD);
        level.set_easing_duration (NibblesGame.GAMEDELAY * 20);
        level.set_scale (0.4f, 0.4f);
        level.set_pivot_point (0.5f, 0.5f);
        level.set_opacity (0);
        level.restore_easing_state ();
    }

    public void create_name_labels ()
    {
        name_labels = new Clutter.Actor ();
        foreach (var worm in game.worms)
        {
            var color = game.worm_props.get (worm).color;

            /* Translators: the player's number, e.g. "Player 1" or "Player 2". */
            var player_id = _("Player %d").printf (worm.id + 1);
            var label = new Clutter.Text.with_text ("Monospace 10", @"<b>$(player_id)</b>");
            label.set_use_markup (true);
            label.set_color (Clutter.Color.from_string (colorval_name (color)));

            var middle = worm.length / 2;
            if (worm.direction == WormDirection.UP || worm.direction == WormDirection.DOWN)
            {
                label.set_x (worm.list[middle].x * game.tile_size - label.width / 2 + game.tile_size / 2);
                label.set_y (worm.list[middle].y * game.tile_size - 5 * game.tile_size);
            }
            else if (worm.direction == WormDirection.LEFT || worm.direction == WormDirection.RIGHT)
            {
                label.set_x (worm.list[middle].x * game.tile_size - label.width / 2 + game.tile_size / 2);
                label.set_y (worm.head.y * game.tile_size - 3 * game.tile_size);
            }
            name_labels.add (label);
        }

        level.add_child (name_labels);
    }

    /*\
    * * Worms drawing
    \*/

    private void worm_added_cb (Worm worm)
    {
        var actor = new GtkClutter.Texture ();
        try
        {
            actor.set_from_pixbuf (worm_pixmaps[game.worm_props.get (worm).color]);
        }
        catch (Clutter.TextureError e)
        {
            error ("Nibbles failed to set texture: %s", e.message);
        }
        catch (Error e)
        {
            error ("Nibbles failed to set texture: %s", e.message);
        }
        actor.set_size (game.tile_size, game.tile_size);
        actor.set_position (worm.list.first ().x * game.tile_size, worm.list.first ().y * game.tile_size);

        var actors = worm_actors.get (worm);
        actors.add_child (actor);
    }

    private void worm_finish_added_cb (Worm worm)
    {
        var actors = worm_actors.get (worm);

        actors.set_opacity (0);
        actors.set_scale (3.0, 3.0);

        actors.save_easing_state ();
        actors.set_easing_mode (Clutter.AnimationMode.EASE_OUT);
        actors.set_easing_duration (NibblesGame.GAMEDELAY * 20);
        actors.set_scale (1.0, 1.0);
        actors.set_pivot_point (0.5f, 0.5f);
        actors.set_opacity (0xff);
        actors.restore_easing_state ();

        worm.dematerialize (game.board, 3);

        Timeout.add (NibblesGame.GAMEDELAY * 27, () => {
            worm.is_stopped = false;
            return Source.REMOVE;
        });
    }

    private void worm_moved_cb (Worm worm)
    {
        var actors = worm_actors.get (worm);

        var tail_actor = actors.first_child;
        actors.remove_child (tail_actor);
        worm_added_cb (worm);
    }

    private void worm_rescaled_cb (Worm worm, int tile_size)
    {
        float x_pos, y_pos;
        var actors = worm_actors.get (worm);
        if (actors == null)
            return;

        foreach (var actor in actors.get_children ())
        {
            actor.get_position (out x_pos, out y_pos);
            actor.set_position ((x_pos / game.tile_size) * tile_size,
                                (y_pos / game.tile_size) * tile_size);
            actor.set_size (tile_size, tile_size);
        }
    }

    private void worm_died_cb (Worm worm)
    {
        float x, y;
        var group = new Clutter.Actor ();
        var actors = worm_actors.get (worm);
        foreach (var actor in actors.get_children ())
        {
            GtkClutter.Texture texture = new GtkClutter.Texture ();
            var color = game.worm_props.get (worm).color;
            try
            {
                texture.set_from_pixbuf (worm_pixmaps[color]);
            }
            catch (Clutter.TextureError e)
            {
                error ("Nibbles failed to set texture: %s", e.message);
            }
            catch (Error e)
            {
                error ("Nibbles failed to set texture: %s", e.message);
            }

            actor.get_position (out x, out y);

            texture.set_position (x, y);
            texture.set_size (game.tile_size, game.tile_size);
            group.add_child (texture);
        }

        actors.remove_all_children ();

        level.add_child (group);

        group.save_easing_state ();
        group.set_easing_mode (Clutter.AnimationMode.EASE_OUT_QUAD);
        group.set_easing_duration (NibblesGame.GAMEDELAY * 9);
        group.set_scale (2.0f, 2.0f);
        group.set_pivot_point (0.5f, 0.5f);
        group.set_opacity (0);
        group.restore_easing_state ();

        play_sound ("crash");
    }

    private void worm_tail_reduced_cb (Worm worm, int erase_size)
    {
        float x, y;
        var group = new Clutter.Actor ();
        var worm_actors = worm_actors.get (worm);
        var color = game.worm_props.get (worm).color;
        for (int i = 0; i < erase_size; i++)
        {
            var texture = new GtkClutter.Texture ();
            try
            {
                texture.set_from_pixbuf (worm_pixmaps[color]);
            }
            catch (Clutter.TextureError e)
            {
                error ("Nibbles failed to set texture: %s", e.message);
            }
            catch (Error e)
            {
                error ("Nibbles failed to set texture: %s", e.message);
            }

            worm_actors.first_child.get_position (out x, out y);
            worm_actors.remove_child (worm_actors.first_child);

            texture.set_position (x, y);
            texture.set_size (game.tile_size, game.tile_size);
            group.add_child (texture);
        }
        level.add_child (group);

        group.save_easing_state ();
        group.set_easing_mode (Clutter.AnimationMode.EASE_OUT_EXPO);
        group.set_easing_duration (NibblesGame.GAMEDELAY * 25);
        group.set_opacity (0);
        group.restore_easing_state ();
    }

    private void worm_reversed_cb (Worm worm)
    {
        var actors = worm_actors.get (worm);

        var count = 0;
        foreach (var actor in actors.get_children ())
        {
            actor.set_position (worm.list[count].x * game.tile_size, worm.list[count].y * game.tile_size);
            count++;
        }
    }

    /*\
    * * Bonuses drawing
    \*/

    private void bonus_added_cb ()
    {
        /* Last bonus added to the list is the one that needs a texture */
        var bonus = game.boni.bonuses.last ();
        var actor = new BonusTexture ();
        try
        {
            actor.set_from_pixbuf (boni_pixmaps[bonus.type]);
        }
        catch (Clutter.TextureError e)
        {
            error ("Nibbles failed to set texture: %s", e.message);
        }
        catch (Error e)
        {
            error ("Nibbles failed to set texture: %s", e.message);
        }

        actor.set_size (game.tile_size, game.tile_size);
        actor.set_position (bonus.x * game.tile_size, bonus.y * game.tile_size);

        level.add_child (actor);
        if (bonus.type != BonusType.REGULAR)
            play_sound ("appear");

        bonus_actors.set (bonus, actor);
    }

    private void bonus_removed_cb (Bonus bonus)
    {
        var bonus_actor = bonus_actors.get (bonus);
        bonus_actors.unset (bonus);
        bonus_actor.hide ();
        level.remove_child (bonus_actor);
    }

    private void bonus_applied_cb (Bonus bonus, Worm worm)
    {
        var actors = worm_actors.get (worm);
        var actor = actors.last_child;

        actor.save_easing_state ();
        actor.set_easing_mode (Clutter.AnimationMode.EASE_OUT_QUINT);
        actor.set_easing_duration (NibblesGame.GAMEDELAY * 15);
        actor.set_scale (1.45f, 1.45f);
        actor.set_pivot_point (0.5f, 0.5f);
        actor.restore_easing_state ();

        switch (bonus.type)
        {
            case BonusType.REGULAR:
                play_sound ("gobble");
                break;
            case BonusType.DOUBLE:
                play_sound ("bonus");
                break;
            case BonusType.HALF:
                play_sound ("bonus");
                break;
            case BonusType.LIFE:
                play_sound ("life");
                break;
            case BonusType.REVERSE:
                play_sound ("reverse");
                break;
            default:
                assert_not_reached ();
        }
    }

    public void boni_rescale (int tile_size)
    {
        foreach (var bonus in game.boni.bonuses)
        {
            var actor = bonus_actors.get (bonus);
            actor.set_size (tile_size, tile_size);
        }
    }

    /*\
    * * Warps drawing
    \*/

    private void warp_added_cb (Warp warp)
    {
        var actor = new WarpTexture ();
        try
        {
            actor.set_from_pixbuf (boni_pixmaps[BonusType.WARP]);
        }
        catch (Clutter.TextureError e)
        {
            error ("Nibbles failed to set texture: %s", e.message);
        }
        catch (Error e)
        {
            error ("Nibbles failed to set texture: %s", e.message);
        }

        actor.set_size (game.tile_size, game.tile_size);
        actor.set_position (warp.x * game.tile_size, warp.y * game.tile_size);

        level.add_child (actor);

        warp_actors.set (warp, actor);
    }

    public void warps_rescale (int tile_size)
    {
        foreach (var warp in game.warp_manager.warps)
        {
            var actor = warp_actors.get (warp);
            actor.set_size (tile_size, tile_size);
        }
    }

    /*\
    * * Sound
    \*/

    private void play_sound (string name)
    {
        if (is_muted)
            return;

        var filename = @"$(name).ogg";
        var path = Path.build_filename (SOUND_DIRECTORY, filename, null);

        CanberraGtk.play_for_widget (this, 0,
                                     Canberra.PROP_MEDIA_NAME, name,
                                     Canberra.PROP_MEDIA_FILENAME, path);
    }

    public static string colorval_name (int colorval)
    {
        return _(color_lookup[colorval]);
    }
}
