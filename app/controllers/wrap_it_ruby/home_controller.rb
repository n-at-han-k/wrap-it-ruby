# frozen_string_literal: true

module WrapItRuby
  class HomeController < ApplicationController
    before_action :authenticate_user!

    def index
    end
  end
end
