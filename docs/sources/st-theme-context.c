
#include <config.h>

#include "st-private.h"
#include "st-settings.h"
#include "st-texture-cache.h"
#include "st-theme.h"
#include "st-theme-context.h"
#include "st-theme-node-private.h"

#define ACCENT_COLOR_BLUE   "#3584e4"
#define ACCENT_COLOR_TEAL   "#2190a4"
#define ACCENT_COLOR_GREEN  "#3a944a"
#define ACCENT_COLOR_YELLOW "#c88800"
#define ACCENT_COLOR_ORANGE "#ed5b00"
#define ACCENT_COLOR_RED    "#e62d42"
#define ACCENT_COLOR_PINK   "#d56199"
#define ACCENT_COLOR_PURPLE "#9141ac"
#define ACCENT_COLOR_SLATE  "#6f8396"

#define ACCENT_FG_COLOR     "#ffffff"

struct _StThemeContext {
  GObject parent;

  ClutterBackend *clutter_backend;

  PangoFontDescription *font;
  CoglColor accent_color;
  CoglColor accent_fg_color;

  StThemeNode *root_node;
  StTheme *theme;

  GHashTable *nodes;

  gulong stylesheets_changed_id;

  int scale_factor;
};

enum
{
  PROP_0,
  PROP_SCALE_FACTOR,

  N_PROPS
};

static GParamSpec *props[N_PROPS] = { NULL, };

enum
{
  CHANGED,

  LAST_SIGNAL
};

static guint signals[LAST_SIGNAL] = { 0, };

G_DEFINE_TYPE (StThemeContext, st_theme_context, G_TYPE_OBJECT)

static PangoFontDescription *get_interface_font_description (void);
static void on_font_name_changed (StSettings     *settings,
                                  GParamSpec     *pspec,
                                  StThemeContext *context);
static void update_accent_colors (StThemeContext *context);
static void on_icon_theme_changed (StTextureCache *cache,
                                   StThemeContext *context);
static void st_theme_context_changed (StThemeContext *context);

static void st_theme_context_set_property (GObject      *object,
                                           guint         prop_id,
                                           const GValue *value,
                                           GParamSpec   *pspec);
static void st_theme_context_get_property (GObject      *object,
                                           guint         prop_id,
                                           GValue       *value,
                                           GParamSpec   *pspec);


static void
st_theme_context_finalize (GObject *object)
{
  StThemeContext *context = ST_THEME_CONTEXT (object);

  g_signal_handlers_disconnect_by_func (st_settings_get (),
                                        (gpointer) on_font_name_changed,
                                        context);
  g_signal_handlers_disconnect_by_func (st_settings_get (),
                                        (gpointer) update_accent_colors,
                                        context);
  g_signal_handlers_disconnect_by_func (st_texture_cache_get_default (),
                                       (gpointer) on_icon_theme_changed,
                                       context);
  g_signal_handlers_disconnect_by_func (context->clutter_backend,
                                        (gpointer) st_theme_context_changed,
                                        context);

  g_clear_signal_handler (&context->stylesheets_changed_id, context->theme);

  if (context->nodes)
    g_hash_table_unref (context->nodes);
  if (context->root_node)
    g_object_unref (context->root_node);
  if (context->theme)
    g_object_unref (context->theme);

  pango_font_description_free (context->font);

  G_OBJECT_CLASS (st_theme_context_parent_class)->finalize (object);
}

static void
st_theme_context_class_init (StThemeContextClass *klass)
{
  GObjectClass *object_class = G_OBJECT_CLASS (klass);

  object_class->set_property = st_theme_context_set_property;
  object_class->get_property = st_theme_context_get_property;
  object_class->finalize = st_theme_context_finalize;

  props[PROP_SCALE_FACTOR] =
    g_param_spec_int ("scale-factor", NULL, NULL,
                      0, G_MAXINT, 1,
                      ST_PARAM_READWRITE | G_PARAM_EXPLICIT_NOTIFY);

  g_object_class_install_properties (object_class, N_PROPS, props);

  signals[CHANGED] =
    g_signal_new ("changed",
                  G_TYPE_FROM_CLASS (klass),
                  G_SIGNAL_RUN_LAST,
                  0,
                  NULL, NULL, NULL,
                  G_TYPE_NONE, 0);
}

static void
st_theme_context_init (StThemeContext *context)
{
  context->font = get_interface_font_description ();

  g_signal_connect (st_settings_get (),
                    "notify::font-name",
                    G_CALLBACK (on_font_name_changed),
                    context);
  g_signal_connect_swapped (st_settings_get (),
                            "notify::accent-color",
                            G_CALLBACK (update_accent_colors),
                            context);
  g_signal_connect (st_texture_cache_get_default (),
                    "icon-theme-changed",
                    G_CALLBACK (on_icon_theme_changed),
                    context);

  context->nodes = g_hash_table_new_full ((GHashFunc) st_theme_node_hash,
                                          (GEqualFunc) st_theme_node_equal,
                                          g_object_unref, NULL);
  context->scale_factor = 1;

  update_accent_colors (context);
}

static void
st_theme_context_set_property (GObject      *object,
                               guint         prop_id,
                               const GValue *value,
                               GParamSpec   *pspec)
{
  StThemeContext *context = ST_THEME_CONTEXT (object);

  switch (prop_id)
    {
    case PROP_SCALE_FACTOR:
      st_theme_context_set_scale_factor (context, g_value_get_int (value));
      break;
    default:
      G_OBJECT_WARN_INVALID_PROPERTY_ID (object, prop_id, pspec);
      break;
    }
}

static void
st_theme_context_get_property (GObject    *object,
                               guint       prop_id,
                               GValue     *value,
                               GParamSpec *pspec)
{
  StThemeContext *context = ST_THEME_CONTEXT (object);

  switch (prop_id)
    {
    case PROP_SCALE_FACTOR:
      g_value_set_int (value, context->scale_factor);
      break;
    default:
      G_OBJECT_WARN_INVALID_PROPERTY_ID (object, prop_id, pspec);
      break;
    }
}

static PangoFontDescription *
get_interface_font_description (void)
{
  StSettings *settings = st_settings_get ();
  g_autofree char *font_name = NULL;

  g_object_get (settings, "font-name", &font_name, NULL);
  return pango_font_description_from_string (font_name);
}

static void
update_accent_colors (StThemeContext *context)
{
  StSettings *settings = st_settings_get ();
  StSystemAccentColor accent_color;

  g_object_get (settings, "accent-color", &accent_color, NULL);

  switch (accent_color)
    {
    case ST_SYSTEM_ACCENT_COLOR_BLUE:
      cogl_color_from_string (&context->accent_color, ACCENT_COLOR_BLUE);
      break;

    case ST_SYSTEM_ACCENT_COLOR_TEAL:
      cogl_color_from_string (&context->accent_color, ACCENT_COLOR_TEAL);
      break;

    case ST_SYSTEM_ACCENT_COLOR_GREEN:
      cogl_color_from_string (&context->accent_color, ACCENT_COLOR_GREEN);
      break;

    case ST_SYSTEM_ACCENT_COLOR_YELLOW:
      cogl_color_from_string (&context->accent_color, ACCENT_COLOR_YELLOW);
      break;

    case ST_SYSTEM_ACCENT_COLOR_ORANGE:
      cogl_color_from_string (&context->accent_color, ACCENT_COLOR_ORANGE);
      break;

    case ST_SYSTEM_ACCENT_COLOR_RED:
      cogl_color_from_string (&context->accent_color, ACCENT_COLOR_RED);
      break;

    case ST_SYSTEM_ACCENT_COLOR_PINK:
      cogl_color_from_string (&context->accent_color, ACCENT_COLOR_PINK);
      break;

    case ST_SYSTEM_ACCENT_COLOR_PURPLE:
      cogl_color_from_string (&context->accent_color, ACCENT_COLOR_PURPLE);
      break;

    case ST_SYSTEM_ACCENT_COLOR_SLATE:
      cogl_color_from_string (&context->accent_color, ACCENT_COLOR_SLATE);
      break;

    default:
      g_warning ("Unsupported accent color: %d", accent_color);
      cogl_color_from_string (&context->accent_color, ACCENT_COLOR_BLUE);
      break;
    }

  cogl_color_from_string (&context->accent_fg_color, ACCENT_FG_COLOR);

  st_theme_context_changed (context);
}

static void
on_stage_destroy (ClutterStage *stage)
{
  StThemeContext *context = st_theme_context_get_for_stage (stage);

  g_object_set_data (G_OBJECT (stage), "st-theme-context", NULL);
  g_object_unref (context);
}

static void
st_theme_context_changed (StThemeContext *context)
{
  StThemeNode *old_root = context->root_node;
  g_autoptr (GPtrArray) old_nodes = NULL;

  context->root_node = NULL;
  old_nodes = g_hash_table_steal_all_keys (context->nodes);

  g_signal_emit (context, signals[CHANGED], 0);

  g_ptr_array_foreach (old_nodes, (GFunc) g_object_run_dispose, NULL);

  if (old_root)
    g_object_unref (old_root);
}

static void
on_font_name_changed (StSettings     *settings,
                      GParamSpec     *pspect,
                      StThemeContext *context)
{
  PangoFontDescription *font_desc = get_interface_font_description ();
  st_theme_context_set_font (context, font_desc);

  pango_font_description_free (font_desc);
}

static void
on_icon_theme_changed (StTextureCache *cache,
                       StThemeContext *context)
{
  guint id;

  id = g_idle_add_once ((GSourceOnceFunc) st_theme_context_changed, context);
  g_source_set_name_by_id (id, "[gnome-shell] st_theme_context_changed");
}

StThemeContext *
st_theme_context_get_for_stage (ClutterStage *stage)
{
  StThemeContext *context;
  ClutterContext *clutter_context;

  g_return_val_if_fail (CLUTTER_IS_STAGE (stage), NULL);

  context = g_object_get_data (G_OBJECT (stage), "st-theme-context");
  if (context)
    return context;

  clutter_context = clutter_actor_get_context (CLUTTER_ACTOR (stage));

  context = g_object_new (ST_TYPE_THEME_CONTEXT, NULL);
  context->clutter_backend = clutter_context_get_backend (clutter_context);

  g_object_set_data (G_OBJECT (stage), "st-theme-context", context);
  g_signal_connect (stage, "destroy",
                    G_CALLBACK (on_stage_destroy), NULL);
  g_signal_connect_swapped (context->clutter_backend,
                            "resolution-changed",
                            G_CALLBACK (st_theme_context_changed),
                            context);

  return context;
}

void
st_theme_context_set_theme (StThemeContext          *context,
                            StTheme                 *theme)
{
  g_return_if_fail (ST_IS_THEME_CONTEXT (context));
  g_return_if_fail (theme == NULL || ST_IS_THEME (theme));

  if (context->theme != theme)
    {
      if (context->theme)
        g_clear_signal_handler (&context->stylesheets_changed_id, context->theme);

      g_set_object (&context->theme, theme);

      if (context->theme)
        {
          context->stylesheets_changed_id =
            g_signal_connect_swapped (context->theme,
                                      "custom-stylesheets-changed",
                                      G_CALLBACK (st_theme_context_changed),
                                      context);
        }

      st_theme_context_changed (context);
    }
}

StTheme *
st_theme_context_get_theme (StThemeContext *context)
{
  g_return_val_if_fail (ST_IS_THEME_CONTEXT (context), NULL);

  return context->theme;
}

void
st_theme_context_set_font (StThemeContext             *context,
                           const PangoFontDescription *font)
{
  g_return_if_fail (ST_IS_THEME_CONTEXT (context));
  g_return_if_fail (font != NULL);

  if (context->font == font ||
      pango_font_description_equal (context->font, font))
    return;

  pango_font_description_free (context->font);
  context->font = pango_font_description_copy (font);
  st_theme_context_changed (context);
}

const PangoFontDescription *
st_theme_context_get_font (StThemeContext *context)
{
  g_return_val_if_fail (ST_IS_THEME_CONTEXT (context), NULL);

  return context->font;
}

void
st_theme_context_get_accent_color (StThemeContext *context,
                                   CoglColor      *color,
                                   CoglColor      *fg_color)
{
  g_return_if_fail (ST_IS_THEME_CONTEXT (context));

  if (color)
    memcpy (color, &context->accent_color, sizeof (CoglColor));

  if (fg_color)
    memcpy (fg_color, &context->accent_fg_color, sizeof (CoglColor));
}

StThemeNode *
st_theme_context_get_root_node (StThemeContext *context)
{
  if (context->root_node == NULL)
    context->root_node = st_theme_node_new (context, NULL, context->theme,
                                            G_TYPE_NONE, NULL, NULL, NULL, NULL);

  return context->root_node;
}

StThemeNode *
st_theme_context_intern_node (StThemeContext *context,
                              StThemeNode    *node)
{
  StThemeNode *mine = g_hash_table_lookup (context->nodes, node);

  if (mine != NULL)
    return mine;

  g_hash_table_add (context->nodes, g_object_ref (node));
  return node;
}

int
st_theme_context_get_scale_factor (StThemeContext *context)
{
  g_return_val_if_fail (ST_IS_THEME_CONTEXT (context), -1);

  return context->scale_factor;
}

void
st_theme_context_set_scale_factor (StThemeContext *context,
                                   int             scale_factor)
{
  g_return_if_fail (ST_IS_THEME_CONTEXT (context));

  if (scale_factor == context->scale_factor)
    return;

  context->scale_factor = scale_factor;
  g_object_notify_by_pspec (G_OBJECT (context), props[PROP_SCALE_FACTOR]);
  st_theme_context_changed (context);
}

double
st_theme_context_get_resolution (StThemeContext *context)
{
  g_return_val_if_fail (ST_IS_THEME_CONTEXT (context), -1);

  return clutter_backend_get_resolution (context->clutter_backend);
}
