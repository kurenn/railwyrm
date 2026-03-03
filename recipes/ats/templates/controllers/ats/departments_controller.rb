# frozen_string_literal: true

module Ats
  class DepartmentsController < BaseController
    before_action :set_department, only: %i[edit update]

    def index
      authorize Department
      @departments = Department.includes(:company).order(:name)
    end

    def new
      @department = Department.new
      authorize @department
    end

    def create
      @department = Department.new(department_params)
      @department.company ||= current_company || Company.first
      authorize @department

      if @department.save
        redirect_to departments_path, notice: "Department created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      authorize @department
    end

    def update
      authorize @department

      if @department.update(department_params)
        redirect_to departments_path, notice: "Department updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_department
      @department = Department.find(params[:id])
    end

    def department_params
      params.require(:department).permit(:name)
    end
  end
end
