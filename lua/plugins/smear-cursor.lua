-- Animated cursor trail. Ported from config/plugins.vim and init.vim section 12.

return {
  {
    "sphamba/smear-cursor.nvim",
    opts = {
      smear_between_buffers = true,
      smear_insert_mode = true,
      stiffness = 0.8,
      trailing_stiffness = 0.6,
      damping = 0.95,
      matrix_pixel_threshold = 0.5,
      stiffness_insert_mode = 0.7,
      trailing_stiffness_insert_mode = 0.7,
      damping_insert_mode = 0.95,
      distance_stop_animating = 0.5,
      time_interval = 7,
    },
  },
}
