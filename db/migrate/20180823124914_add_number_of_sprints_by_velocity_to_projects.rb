class AddNumberOfSprintsByVelocityToProjects < ActiveRecord::Migration
  def change
    add_column :projects, :number_of_sprints_by_velocity, :integer, default: 3
  end
end
