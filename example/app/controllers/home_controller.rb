class HomeController < ApplicationController
  def index
    render plain: "WrapItRuby Example App - visit /example to see the proxy"
  end
end
