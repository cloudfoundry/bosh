package task_test

import (
	"encoding/json"
	"errors"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	boshtask "bosh/agent/task"
	boshlog "bosh/logger"
	fakesys "bosh/system/fakes"
)

func init() {
	Describe("concreteManagerProvider", func() {
		Describe("NewManager", func() {
			It("returns manager with tasks.json as its tasks path", func() {
				logger := boshlog.NewLogger(boshlog.LevelNone)
				fs := fakesys.NewFakeFileSystem()

				taskInfo := boshtask.TaskInfo{
					TaskID:  "fake-task-id",
					Method:  "fake-method",
					Payload: []byte("fake-payload"),
				}

				manager := boshtask.NewManagerProvider().NewManager(logger, fs, "/dir/path")
				err := manager.AddTaskInfo(taskInfo)
				Expect(err).ToNot(HaveOccurred())

				// Check expected file location with another manager
				otherManager := boshtask.NewManager(logger, fs, "/dir/path/tasks.json")

				taskInfos, err := otherManager.GetTaskInfos()
				Expect(err).ToNot(HaveOccurred())
				Expect(taskInfos).To(Equal([]boshtask.TaskInfo{taskInfo}))
			})
		})
	})

	Describe("concreteManager", func() {
		var (
			logger  boshlog.Logger
			fs      *fakesys.FakeFileSystem
			manager boshtask.Manager
		)

		BeforeEach(func() {
			logger = boshlog.NewLogger(boshlog.LevelNone)
			fs = fakesys.NewFakeFileSystem()
			manager = boshtask.NewManager(logger, fs, "/dir/path")
		})

		Describe("GetTaskInfos", func() {
			It("can load multiple tasks", func() {
				err := manager.AddTaskInfo(boshtask.TaskInfo{
					TaskID:  "fake-task-id-1",
					Method:  "fake-method-1",
					Payload: []byte("fake-payload-1"),
				})
				Expect(err).ToNot(HaveOccurred())

				err = manager.AddTaskInfo(boshtask.TaskInfo{
					TaskID:  "fake-task-id-2",
					Method:  "fake-method-2",
					Payload: []byte("fake-payload-2"),
				})
				Expect(err).ToNot(HaveOccurred())

				// Make sure we are not getting cached copy of taskInfos
				reloadedManager := boshtask.NewManager(logger, fs, "/dir/path")

				taskInfos, err := reloadedManager.GetTaskInfos()
				Expect(err).ToNot(HaveOccurred())
				Expect(taskInfos).To(Equal([]boshtask.TaskInfo{
					boshtask.TaskInfo{
						TaskID:  "fake-task-id-1",
						Method:  "fake-method-1",
						Payload: []byte("fake-payload-1"),
					},
					boshtask.TaskInfo{
						TaskID:  "fake-task-id-2",
						Method:  "fake-method-2",
						Payload: []byte("fake-payload-2"),
					},
				}))
			})

			It("succeeds when there is no tasks (file is not present)", func() {
				taskInfos, err := manager.GetTaskInfos()
				Expect(err).ToNot(HaveOccurred())
				Expect(len(taskInfos)).To(Equal(0))
			})

			It("returns an error when failing to load tasks from the file that exists", func() {
				err := manager.AddTaskInfo(boshtask.TaskInfo{
					TaskID:  "fake-task-id-2",
					Method:  "fake-method-2",
					Payload: []byte("fake-payload-2"),
				})
				Expect(err).ToNot(HaveOccurred())

				fs.ReadFileError = errors.New("fake-read-error")

				_, err = manager.GetTaskInfos()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fake-read-error"))
			})
		})

		Describe("AddTaskInfo", func() {
			It("can add multiple tasks", func() {
				err := manager.AddTaskInfo(boshtask.TaskInfo{
					TaskID:  "fake-task-id-1",
					Method:  "fake-method-1",
					Payload: []byte("fake-payload-1"),
				})
				Expect(err).ToNot(HaveOccurred())

				err = manager.AddTaskInfo(boshtask.TaskInfo{
					TaskID:  "fake-task-id-2",
					Method:  "fake-method-2",
					Payload: []byte("fake-payload-2"),
				})
				Expect(err).ToNot(HaveOccurred())

				content, err := fs.ReadFile("/dir/path")
				Expect(err).ToNot(HaveOccurred())

				var decodedMap map[string]boshtask.TaskInfo

				err = json.Unmarshal(content, &decodedMap)
				Expect(err).ToNot(HaveOccurred())
				Expect(decodedMap).To(Equal(map[string]boshtask.TaskInfo{
					"fake-task-id-1": boshtask.TaskInfo{
						TaskID:  "fake-task-id-1",
						Method:  "fake-method-1",
						Payload: []byte("fake-payload-1"),
					},
					"fake-task-id-2": boshtask.TaskInfo{
						TaskID:  "fake-task-id-2",
						Method:  "fake-method-2",
						Payload: []byte("fake-payload-2"),
					},
				}))
			})

			It("returns an error when failing to save task", func() {
				fs.WriteToFileError = errors.New("fake-write-error")

				err := manager.AddTaskInfo(boshtask.TaskInfo{
					TaskID:  "fake-task-id",
					Method:  "fake-method",
					Payload: []byte("fake-payload"),
				})
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fake-write-error"))
			})
		})

		Describe("RemoveTaskInfo", func() {
			BeforeEach(func() {
				err := manager.AddTaskInfo(boshtask.TaskInfo{
					TaskID:  "fake-task-id-1",
					Method:  "fake-method-1",
					Payload: []byte("fake-payload-1"),
				})
				Expect(err).ToNot(HaveOccurred())

				err = manager.AddTaskInfo(boshtask.TaskInfo{
					TaskID:  "fake-task-id-2",
					Method:  "fake-method-2",
					Payload: []byte("fake-payload-2"),
				})
				Expect(err).ToNot(HaveOccurred())
			})

			It("removes the task", func() {
				err := manager.RemoveTaskInfo("fake-task-id-1")
				Expect(err).ToNot(HaveOccurred())

				content, err := fs.ReadFile("/dir/path")
				Expect(err).ToNot(HaveOccurred())

				var decodedMap map[string]boshtask.TaskInfo

				err = json.Unmarshal(content, &decodedMap)
				Expect(err).ToNot(HaveOccurred())
				Expect(decodedMap).To(Equal(map[string]boshtask.TaskInfo{
					"fake-task-id-2": boshtask.TaskInfo{
						TaskID:  "fake-task-id-2",
						Method:  "fake-method-2",
						Payload: []byte("fake-payload-2"),
					},
				}))
			})

			It("does not return error when removing task that does not exist", func() {
				err := manager.RemoveTaskInfo("fake-unknown-task-id")
				Expect(err).ToNot(HaveOccurred())
			})

			It("returns an error when failing to remove task", func() {
				fs.WriteToFileError = errors.New("fake-write-error")

				err := manager.RemoveTaskInfo("fake-task-id")
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fake-write-error"))
			})
		})
	})
}
