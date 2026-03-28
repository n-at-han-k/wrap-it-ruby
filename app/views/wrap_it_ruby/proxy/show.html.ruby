iframe_allow = %w[
  accelerometer
  autoplay
  camera
  clipboard-read
  clipboard-write
  compute-pressure
  cross-origin-isolated
  display-capture
  encrypted-media
  fullscreen
  gamepad
  geolocation
  gyroscope
  hid
  identity-credentials-get
  idle-detection
  local-fonts
  magnetometer
  microphone
  midi
  payment
  picture-in-picture
  publickey-credentials-create
  publickey-credentials-get
  screen-wake-lock
  serial
  storage-access
  usb
  window-management
  xr-spatial-tracking
].join("; ")

output_buffer << turbo_frame_tag("proxy-content") do
  tag.div(class: 'iframe-wrapper') do
    tag.iframe(
      src: @iframe_src,
      allow: iframe_allow
    )
  end
end
