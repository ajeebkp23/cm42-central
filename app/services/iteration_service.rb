class IterationService
  DAYS_IN_WEEK = (1.week / 1.day)

  attr_reader :project, :stories

  delegate :start_date, :start_date=,
    :iteration_length, :iteration_length=,
    :iteration_start_day, :iteration_start_day=,
    to: :project

  def initialize(project)
    @project = project
    @stories = project.stories.includes(:owned_by).
      where.not(accepted_at: nil).
      order(:accepted_at).
      to_a
    calculate_iterations!
    fix_owner!
  end

  def iteration_start_date
    iteration_start_date = start_date.beginning_of_day
    if start_date.wday != iteration_start_day
      day_difference = start_date.wday - iteration_start_day
      day_difference += DAYS_IN_WEEK if day_difference < 0
      iteration_start_date -= day_difference.days
    end
    iteration_start_date
  end

  def iteration_number_for_date(compare_date)
    compare_date = compare_date.to_time if compare_date.is_a?(Date)
    days_apart = ( compare_date - iteration_start_date ) / 1.day
    days_in_iteration = iteration_length * DAYS_IN_WEEK
    ( days_apart / days_in_iteration ).floor + 1
  end

  def date_for_iteration_number(iteration_number)
    difference = (iteration_length * DAYS_IN_WEEK) * (iteration_number - 1)
    iteration_start_date + difference.days
  end

  def calculate_iterations!
    @stories.each do |record|
      iteration_number = iteration_number_for_date(record.accepted_at)
      iteration_start_date = date_for_iteration_number(iteration_number)
      record.iteration_number = iteration_number
      record.iteration_start_date = iteration_start_date
    end
  end

  def fix_owner!
    @dummy_user ||= User.find_or_create_by!(username: "dummy", email: "dummy@foo.com", name: "Dummy")
    @stories.each do |record|
      record.owned_by = @dummy_user if record.owned_by.nil?
    end
  end

  def group_by_iteration
    @group_by_iteration ||= @stories.
      group_by { |story| story.iteration_number }.
      reduce({}) do |group, iteration|
        points = iteration.last.
          map { |story|
            if %w(chore bug).include? story.story_type
              0
            else
              story.estimate
            end
          }
        group.merge(iteration.first => points)
      end
  end

  def group_by_velocity
    @group_by_velocity ||= group_by_iteration.keys.reduce({}) do |group, key|
      group.merge(key => group_by_iteration[key].reduce(&:+))
    end
  end

  def velocity
    @velocity ||= begin
      iterations = group_by_iteration.size
      iteration = 3 if iterations > 3
      sum = group_by_velocity.values.slice((-1 * iteration)..-1).
        reduce(0) { |total, points| total + points }
      stories = group_by_iteration.values.slice((-1 * iteration)..-1).
        reduce(0) { |total, stories| total + stories.size }
      velocity = (sum / stories).floor
      velocity < 1 ? 1 : velocity
    end
  end

  def group_by_developer
    @group_by_developer ||= @stories.
      group_by { |o| o.owned_by.name }.
      reduce([]) do |group, owner|
        data = owner.last.group_by { |story| story.iteration_number }.
          reduce({}) do |group, iteration|
            points = iteration.last.
              map { |story|
                if %w(chore bug).include? story.story_type
                  0
                else
                  story.estimate
                end
              }.
              reduce(&:+)
            group.merge(iteration.first => points)
          end
        group << { name: owner.first, data: data }
      end
  end
end
