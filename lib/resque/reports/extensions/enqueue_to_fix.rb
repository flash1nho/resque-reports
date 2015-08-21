# coding: utf-8
require 'resque/plugins/progress'

module Resque
  module Reports
    module Extensions
      module EnqueueToFix
        def self.extended(base)
          base.extend(Resque::Plugins::Progress)
          base.extend(ClassMethods)
        end

        module ClassMethods
          def enqueue_to(*args) #:nodoc:
            queue = args.shift
            meta = enqueued?(*args)
            return meta if meta.present?

            meta = Resque::Plugins::Meta::Metadata.new({'meta_id' => meta_id(args), 'job_class' => self.to_s})
            meta.save

            Resque.enqueue_to(queue, self, meta.meta_id, *args)
            meta
          end
        end
      end
    end
  end
end
