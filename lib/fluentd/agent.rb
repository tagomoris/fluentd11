#
# Fluentd
#
# Copyright (C) 2011-2013 FURUHASHI Sadayuki
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.
#
module Fluentd

  #
  # Agent is the base class of input, output and filter plugins.
  #
  # Agent forms a tree structure:
  #
  # Agent A
  #  #agents --+--> Agent B
  #            |     #agents --+--> Agent D
  #            |               |     #agents --> []
  #            |               |
  #            |               +--> Agent E
  #            |                     #agents --> []
  #            +--> Agent C
  #                  #agents --> []
  #
  # The root agent is RootAgent. See also root_agent.rb.
  #
  # In signle process mode, all agents are assigned to one Processor.
  # In multiprocess mode, each agent is assigned to one or more Processor:
  #
  # ProcessManager
  #  #processors
  #    |
  #    +--> Processor 1
  #    |     #agents --+--> Agent A
  #    |               |
  #    |               +--> Agent C
  #    |
  #    +--> Processor 2
  #    |     #agents --+--> Agent A
  #    |               |
  #    |               +--> Agent B
  #    |               |
  #    .               +--> Agent D
  #    .               |
  #    .               +--> Agent E
  #
  # * Processor assignment considers locality of agents.
  #
  # * ProcessManager assigns agents into processors.
  #   See also process_manager.rb.
  #

  class Agent
    include Configurable

    def initialize
      @agents = []
      @stats_collector = NullStatsCollector.new
      init_configurable
      super
    end

    attr_reader :agents

    attr_accessor :stats_collector
    alias_method :stats, :stats_collector

    def configure(conf)
      super
    end

    def add_agent(agent)
      # inherit stats_collector (RootAgent#initialize is the node that sets the actual stats_collector)
      agent.stats_collector = @stats_collector
      @agents << agent
      self
    end

    def start
    end

    def stop
    end

    def shutdown
    end
  end

end
