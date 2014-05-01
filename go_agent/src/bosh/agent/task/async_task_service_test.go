package task_test

import (
	"errors"
	"fmt"
	"time"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/agent/task"
	boshlog "bosh/logger"
	fakeuuid "bosh/uuid/fakes"
)

func init() {
	Describe("asyncTaskService", func() {
		var (
			uuidGen *fakeuuid.FakeGenerator
			service Service
		)

		BeforeEach(func() {
			uuidGen = &fakeuuid.FakeGenerator{}
			service = NewAsyncTaskService(uuidGen, boshlog.NewLogger(boshlog.LevelNone))
		})

		Describe("StartTask", func() {
			startAndWaitForTaskCompletion := func(task Task) Task {
				service.StartTask(task)
				for task.State == TaskStateRunning {
					time.Sleep(time.Nanosecond)
					task, _ = service.FindTaskWithID(task.ID)
				}
				return task
			}

			It("sets return value on a successful task", func() {
				runFunc := func() (interface{}, error) { return 123, nil }

				task, err := service.CreateTask(runFunc, nil, nil)
				Expect(err).ToNot(HaveOccurred())

				task = startAndWaitForTaskCompletion(task)
				Expect(task.State).To(BeEquivalentTo(TaskStateDone))
				Expect(task.Value).To(Equal(123))
				Expect(task.Error).To(BeNil())
			})

			It("sets task error on a failing task", func() {
				err := errors.New("fake-error")
				runFunc := func() (interface{}, error) { return nil, err }

				task, createErr := service.CreateTask(runFunc, nil, nil)
				Expect(createErr).ToNot(HaveOccurred())

				task = startAndWaitForTaskCompletion(task)
				Expect(task.State).To(BeEquivalentTo(TaskStateFailed))
				Expect(task.Value).To(BeNil())
				Expect(task.Error).To(Equal(err))
			})

			Describe("CreateTask", func() {
				It("can run task created with CreateTask which does not have end func", func() {
					ranFunc := false
					runFunc := func() (interface{}, error) { ranFunc = true; return nil, nil }

					task, err := service.CreateTask(runFunc, nil, nil)
					Expect(err).ToNot(HaveOccurred())

					startAndWaitForTaskCompletion(task)
					Expect(ranFunc).To(BeTrue())
				})

				It("can run task created with CreateTask which has end func", func() {
					ranFunc := false
					runFunc := func() (interface{}, error) { ranFunc = true; return nil, nil }

					ranEndFunc := false
					endFunc := func(Task) { ranEndFunc = true }

					task, err := service.CreateTask(runFunc, nil, endFunc)
					Expect(err).ToNot(HaveOccurred())

					startAndWaitForTaskCompletion(task)
					Expect(ranFunc).To(BeTrue())
					Expect(ranEndFunc).To(BeTrue())
				})

				It("returns an error if generate uuid fails", func() {
					uuidGen.GenerateError = errors.New("fake-generate-uuid-error")
					_, err := service.CreateTask(nil, nil, nil)
					Expect(err).To(HaveOccurred())
					Expect(err.Error()).To(ContainSubstring("fake-generate-uuid-error"))
				})
			})

			Describe("CreateTaskWithID", func() {
				It("can run task created with CreateTaskWithID which does not have end func", func() {
					ranFunc := false
					runFunc := func() (interface{}, error) { ranFunc = true; return nil, nil }

					task := service.CreateTaskWithID("fake-task-id", runFunc, nil, nil)

					startAndWaitForTaskCompletion(task)
					Expect(ranFunc).To(BeTrue())
				})

				It("can run task created with CreateTaskWithID which has end func", func() {
					ranFunc := false
					runFunc := func() (interface{}, error) { ranFunc = true; return nil, nil }

					ranEndFunc := false
					endFunc := func(Task) { ranEndFunc = true }

					task := service.CreateTaskWithID("fake-task-id", runFunc, nil, endFunc)

					startAndWaitForTaskCompletion(task)
					Expect(ranFunc).To(BeTrue())
					Expect(ranEndFunc).To(BeTrue())
				})
			})

			It("can process many tasks simultaneously", func() {
				taskFunc := func() (interface{}, error) {
					time.Sleep(10 * time.Millisecond)
					return nil, nil
				}

				ids := []string{}
				for id := 1; id < 200; id++ {
					idStr := fmt.Sprintf("%d", id)
					uuidGen.GeneratedUuid = idStr
					ids = append(ids, idStr)

					task, err := service.CreateTask(taskFunc, nil, nil)
					Expect(err).ToNot(HaveOccurred())
					go service.StartTask(task)
				}

				for {
					allDone := true
					for _, id := range ids {
						task, _ := service.FindTaskWithID(id)
						if task.State != TaskStateDone {
							allDone = false
							break
						}
					}

					if allDone {
						break
					}
					time.Sleep(200 * time.Millisecond)
				}
			})
		})

		Describe("CreateTask", func() {
			It("creates a task with auto-assigned id", func() {
				uuidGen.GeneratedUuid = "fake-uuid"

				runFuncCalled := false
				runFunc := func() (interface{}, error) {
					runFuncCalled = true
					return nil, nil
				}

				cancelFuncCalled := false
				cancelFunc := func(_ Task) error {
					cancelFuncCalled = true
					return nil
				}

				endFuncCalled := false
				endFunc := func(_ Task) {
					endFuncCalled = true
				}

				task, err := service.CreateTask(runFunc, cancelFunc, endFunc)
				Expect(err).ToNot(HaveOccurred())
				Expect(task.ID).To(Equal("fake-uuid"))
				Expect(task.State).To(Equal(TaskStateRunning))

				task.TaskFunc()
				Expect(runFuncCalled).To(BeTrue())

				task.CancelFunc(task)
				Expect(cancelFuncCalled).To(BeTrue())

				task.TaskEndFunc(task)
				Expect(endFuncCalled).To(BeTrue())
			})
		})

		Describe("CreateTaskWithID", func() {
			It("creates a task with given id", func() {
				runFuncCalled := false
				runFunc := func() (interface{}, error) {
					runFuncCalled = true
					return nil, nil
				}

				cancelFuncCalled := false
				cancelFunc := func(_ Task) error {
					cancelFuncCalled = true
					return nil
				}

				endFuncCalled := false
				endFunc := func(_ Task) {
					endFuncCalled = true
				}

				task := service.CreateTaskWithID("fake-task-id", runFunc, cancelFunc, endFunc)
				Expect(task.ID).To(Equal("fake-task-id"))
				Expect(task.State).To(Equal(TaskStateRunning))

				task.TaskFunc()
				Expect(runFuncCalled).To(BeTrue())

				task.CancelFunc(task)
				Expect(cancelFuncCalled).To(BeTrue())

				task.TaskEndFunc(task)
				Expect(endFuncCalled).To(BeTrue())
			})
		})
	})
}
