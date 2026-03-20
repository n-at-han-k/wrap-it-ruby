output_buffer << turbo_frame_tag("proxy-content") do
  tag.div(class: 'iframe-wrapper') do
    tag.iframe( src: @iframe_src )
  end
end
